// main.bicep - The Orchestrator for landing zone deployment for one environment
targetScope = 'subscription'

@description('Environment for the deployment')
param environmentName string = 'dev'

@description('Location for the resources')
param location string = 'spaincentral' // Default location, can be overridden

@description('Name of the management resource group')
param managementResourceGroupName string = 'rg-ssharer-mgmt-${environmentName}'

@description('Tags for resources')
param tags object = {
  Application: 'Secure Sharer'
  environment: environmentName
}

@description('GitHub organization name to federate with')
param gitHubOrganizationName string

@description('GitHub repository name to federate with')
param gitHubRepositoryName string

@description('GitHub subject pattern to federate with')
param gitHubSubjectPattern string = 'environment:${environmentName}'

// Variables for the role definition IDs

var acrPullRoleDefinitionId = '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/7f951dda-4ed3-4680-a7ca-43fe172d538d' // AcrPull role definition ID
var acrPushRoleDefinitionId = '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/8311e382-0749-4cb8-b61a-304f252e45ec' // AcrPush role definition ID
var ContributorRoleDefinitionId = '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c' // Contributor role definition ID

// Create all resource groups for landing zone
resource hubRG 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-ssharer-artifacts-hub'
  location: location
  tags: {
    Application: 'Secure Sharer'
    environment: 'Shared Artifacts' 
  }
}

resource k8sRG 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-ssharer-k8s-spoke-${environmentName}'
  location: location
  tags: tags
}

resource paasRG 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-ssharer-paas-spoke-${environmentName}'
  location: location
  tags: tags
}


// Create or reference existing management resource group
resource managementRg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: managementResourceGroupName
  location: location
  tags: {
    Application: 'Secure Sharer'
    environment: environmentName
    purpose: 'management'
  }
}


// Create the UAMIs - Split creation between resource groups

// Create UAMIs for workload-specific identities in management RG
module uamisManagement 'common-modules/uami.bicep' = {
  scope: managementRg
  params: {
    uamiLocation: location
    uamiNames: [
      'uami-ssharer-acr-${environmentName}'
      'uami-ssharer-k8s-${environmentName}'
      'uami-ssharer-k8s-deploy-${environmentName}'
      'uami-ssharer-paas-${environmentName}'
    ]
    tags: tags
  }
}

// Create shared infra creator UAMI in hub resource group
module uamiSharedInfra 'common-modules/uami.bicep' = {
  scope: hubRG
  params: {
    uamiLocation: location
    uamiNames: [
      'uami-ssharer-shared-infra-creator'
    ]
    tags: tags
  }
}

// Create workload UAMI to federate with GitHub Actions
// Assigns the required permissions to the UAMI to do operations

// --- 0. User Assigned Managed Identity (UAMI) for ACR ---

// Federate UAMI with GitHub Actions
module acrPushGhFed 'common-modules/github-federation.bicep' = {
  scope: managementRg
  params: {
    UamiName: uamisManagement.outputs.uamiNames[0]
    GitHubOrganizationName: gitHubOrganizationName
    GitHubRepositoryName: gitHubRepositoryName
    gitHubSubjectPattern: gitHubSubjectPattern
  }
}

// Assign the AcrPush role to the UAMI in the shared resource group

module uamiAcrPush 'common-modules/uami-rbac.bicep'= {
  scope: hubRG
  params: {
    uamiPrincipalId: uamisManagement.outputs.uamiPrincipalIds[0]
    roleDefinitionId: acrPushRoleDefinitionId
  }
}

// --- 1. User Assigned Managed Identity (UAMI) for Shared Infrastructure Creator ---

// Federate UAMI with GitHub Actions for shared infrastructure creation
module sharedInfraCreatorGhFed 'common-modules/github-federation.bicep' = {
  scope: hubRG
  params: {
    UamiName: uamiSharedInfra.outputs.uamiNames[0]
    GitHubOrganizationName: gitHubOrganizationName
    GitHubRepositoryName: gitHubRepositoryName
    gitHubSubjectPattern: gitHubSubjectPattern
  }
}

// Assign the Contributor role to the UAMI for shared infrastructure creation in the hub resource group
module uamiSharedInfraCreatorContributor 'common-modules/uami-rbac.bicep'= {
  scope: hubRG
  params: {
    uamiPrincipalId: uamiSharedInfra.outputs.uamiPrincipalIds[0]
    roleDefinitionId: ContributorRoleDefinitionId
  }
}

// --- 2. Create User Assigned Managed Identity (UAMI) for K8S Spoke ---

// Federate UAMI with GitHub Actions
module k8SpokeGhFed 'common-modules/github-federation.bicep' = {
  scope: managementRg
  params: {
    UamiName: uamisManagement.outputs.uamiNames[1]
    GitHubOrganizationName: gitHubOrganizationName
    GitHubRepositoryName: gitHubRepositoryName
    gitHubSubjectPattern: gitHubSubjectPattern
  }
}

// Assign the Contributor role to the UAMI in the k8s resource group

module uamiK8sContributor 'common-modules/uami-rbac.bicep'= {
  scope: k8sRG
  params: {
    uamiPrincipalId: uamisManagement.outputs.uamiPrincipalIds[1]
    roleDefinitionId: ContributorRoleDefinitionId
  }
}

//Assign the ACR PUll role to the UAMI in the k8s resource group

module uamiK8sAcrPull 'common-modules/uami-rbac.bicep'= {
  scope: hubRG
  params: {
    uamiPrincipalId: uamisManagement.outputs.uamiPrincipalIds[1]
    roleDefinitionId: acrPullRoleDefinitionId
  }
}


// --- 3. Create User Assigned Managed Identity (UAMI) for K8S Deployment ---

// Federate UAMI with GitHub Actions
module k8SpokeDeploymentGhFed 'common-modules/github-federation.bicep' = {
  scope: managementRg
  params: {
    UamiName: uamisManagement.outputs.uamiNames[2]
    GitHubOrganizationName: gitHubOrganizationName
    GitHubRepositoryName: gitHubRepositoryName
    gitHubSubjectPattern: gitHubSubjectPattern
  }
}

//Assign the ACR PUll role to the UAMI for k8s deployment
module uamiK8DeploymentsAcrPull 'common-modules/uami-rbac.bicep'= {
  scope: hubRG
  params: {
    uamiPrincipalId: uamisManagement.outputs.uamiPrincipalIds[2]
    roleDefinitionId: acrPullRoleDefinitionId
  }
}
// --- 4. Create User Assigned Managed Identity (UAMI) for PaaS resource group ---

// Federate UAMI with GitHub Actions
module uamiPaasGhFed 'common-modules/github-federation.bicep' = {
  scope: managementRg
  params: {
    UamiName: uamisManagement.outputs.uamiNames[3]
    GitHubOrganizationName: gitHubOrganizationName
    GitHubRepositoryName: gitHubRepositoryName
    gitHubSubjectPattern: gitHubSubjectPattern
  }
}

//Assign the Contributor role to the UAMI for PaaS workload
module uamiPaasContributor 'common-modules/uami-rbac.bicep'= {
  scope: paasRG
  params: {
    uamiPrincipalId: uamisManagement.outputs.uamiPrincipalIds[3]
    roleDefinitionId: ContributorRoleDefinitionId
  }
}

// Assign the AcrPull role to the UAMI for the PaaS workload

module uamiPaasAcrPull 'common-modules/uami-rbac.bicep'= {
  scope: hubRG 
  params: {
    uamiPrincipalId: uamisManagement.outputs.uamiPrincipalIds[3]
    roleDefinitionId: acrPullRoleDefinitionId
  }
}

// Outputs for reference information
output managementResourceGroupName string = managementRg.name
output hubResourceGroupName string = hubRG.name
output k8sResourceGroupName string = k8sRG.name
output paasResourceGroupName string = paasRG.name
output tenantId string = subscription().tenantId
output subscriptionId string = subscription().subscriptionId
output environmentName string = environmentName

// UAMI Outputs
output acrUamiName string = uamisManagement.outputs.uamiNames[0]
output acrUamiPrincipalId string = uamisManagement.outputs.uamiPrincipalIds[0]
output acrUamiClientId string = uamisManagement.outputs.uamiClientIds[0]

output sharedInfraCreatorUamiName string = uamiSharedInfra.outputs.uamiNames[0]
output sharedInfraCreatorUamiPrincipalId string = uamiSharedInfra.outputs.uamiPrincipalIds[0]
output sharedInfraCreatorUamiClientId string = uamiSharedInfra.outputs.uamiClientIds[0]

output k8sUamiName string = uamisManagement.outputs.uamiNames[1]
output k8sUamiPrincipalId string = uamisManagement.outputs.uamiPrincipalIds[1]
output k8sUamiClientId string = uamisManagement.outputs.uamiClientIds[1]

output k8sDeployUamiName string = uamisManagement.outputs.uamiNames[2]
output k8sDeployUamiPrincipalId string = uamisManagement.outputs.uamiPrincipalIds[2]
output k8sDeployUamiClientId string = uamisManagement.outputs.uamiClientIds[2]

output paasUamiName string = uamisManagement.outputs.uamiNames[3]
output paasUamiPrincipalId string = uamisManagement.outputs.uamiPrincipalIds[3]
output paasUamiClientId string = uamisManagement.outputs.uamiClientIds[3]
