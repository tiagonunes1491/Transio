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
param gitHubSubjectPattern string = 'refs/heads/main'

// Variables for the role definition IDs

var acrPullRoleDefinitionId = 'f8b3c0d1-2a4e-4b6c-9f5c-7d8e2f1b3c4d' // AcrPull role definition ID
var acrPushRoleDefinitionId = '8311e382-0749-4cb8-b61a-304f252e45ec' // AcrPush role definition ID
var ContributorRoleDefinitionId = 'b24988ac-6180-42a0-ab88-20f7382dd24c'

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


// reference existing resource group for management
resource managementRg 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  name: managementResourceGroupName
}


// Create the UAMIs 

module uamis 'common-modules/uami.bicep' = {
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

// Create workload UAMI to federate with GitHub Actions
// Assigns the required permissions to the UAMI to do operations

// --- 0. User Assigned Managed Identity (UAMI) for ACR ---

// Federate UAMI with GitHub Actions
module acrPushGhFed 'common-modules/github-federation.bicep' = {
  scope: managementRg
  params: {
    UamiName: uamis.outputs.uamiNames[0]
    GitHubOrganizationName: gitHubOrganizationName
    GitHubRepositoryName: gitHubRepositoryName
    gitHubSubjectPattern: gitHubSubjectPattern
  }
}

// Assign the AcrPush role to the UAMI in the shared resource group

module uamiAcrPush 'common-modules/uami-rbac.bicep'= {
  scope: hubRG
  params: {
    uamiPrincipalId: uamis.outputs.uamiPrincipalIds[0]
    roleDefinitionId: acrPushRoleDefinitionId
  }
}

// --- 2. Create User Assigned Managed Identity (UAMI) for K8S Spoke ---

// Federate UAMI with GitHub Actions
module k8SpokeGhFed 'common-modules/github-federation.bicep' = {
  scope: managementRg
  params: {
    UamiName: uamis.outputs.uamiNames[1]
    GitHubOrganizationName: gitHubOrganizationName
    GitHubRepositoryName: gitHubRepositoryName
    gitHubSubjectPattern: gitHubSubjectPattern
  }
}

// Assign the Contributor role to the UAMI in the k8s resource group

module uamiK8sContributor 'common-modules/uami-rbac.bicep'= {
  scope: k8sRG
  params: {
    uamiPrincipalId: uamis.outputs.uamiPrincipalIds[1]
    roleDefinitionId: ContributorRoleDefinitionId
  }
}

//Assign the ACR PUll role to the UAMI in the k8s resource group

module uamiK8sAcrPull 'common-modules/uami-rbac.bicep'= {
  scope: hubRG
  params: {
    uamiPrincipalId: uamis.outputs.uamiPrincipalIds[1]
    roleDefinitionId: acrPullRoleDefinitionId
  }
}


// --- 3. Create User Assigned Managed Identity (UAMI) for K8S Deployment ---

// Federate UAMI with GitHub Actions
module k8SpokeDeploymentGhFed 'common-modules/github-federation.bicep' = {
  scope: managementRg
  params: {
    UamiName: uamis.outputs.uamiNames[2]
    GitHubOrganizationName: gitHubOrganizationName
    GitHubRepositoryName: gitHubRepositoryName
    gitHubSubjectPattern: gitHubSubjectPattern
  }
}

//Assign the ACR PUll role to the UAMI for k8s deployment
module uamiK8DeploymentsAcrPull 'common-modules/uami-rbac.bicep'= {
  scope: hubRG
  params: {
    uamiPrincipalId: uamis.outputs.uamiPrincipalIds[2]
    roleDefinitionId: acrPullRoleDefinitionId
  }
}
// --- 4. Create User Assigned Managed Identity (UAMI) for PaaS resource group ---

// Federate UAMI with GitHub Actions
module uamiPaasGhFed 'common-modules/github-federation.bicep' = {
  scope: managementRg
  params: {
    UamiName: uamis.outputs.uamiNames[3]
    GitHubOrganizationName: gitHubOrganizationName
    GitHubRepositoryName: gitHubRepositoryName
    gitHubSubjectPattern: gitHubSubjectPattern
  }
}

//Assign the Contributor role to the UAMI for PaaS workload
module uamiPaasContributor 'common-modules/uami-rbac.bicep'= {
  scope: paasRG
  params: {
    uamiPrincipalId: uamis.outputs.uamiPrincipalIds[3]
    roleDefinitionId: ContributorRoleDefinitionId
  }
}

// Assign the AcrPull role to the UAMI for the PaaS workload

module uamiPaasAcrPull 'common-modules/uami-rbac.bicep'= {
  scope: hubRG 
  params: {
    uamiPrincipalId: uamis.outputs.uamiPrincipalIds[3]
    roleDefinitionId: acrPullRoleDefinitionId
  }
}
