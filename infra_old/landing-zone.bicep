// main.bicep - The Orchestrator for landing zone deployment for one environment
// Provisions resource groups, managed identities, federated credentials, and RBAC for a single environment.
targetScope = 'subscription'

// =====================
// Parameters
// =====================

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

@description('Resource group for shared artifacts')
param sharedArtifactsResourceGroupName string = 'rg-ssharer-artifacts-hub'

@description('GitHub workload identities for the environment. Each entry defines a UAMI, its environment, RBAC role, and federation types.')
param workloadIdentities object = {
  k8s: {
    UAMI: 'uami-ssharer-k8s-${environmentName}'
    ENV: environmentName
    ROLE: 'contributor'
    federationTypes: 'environment'
  }
  k8sDeploy: {
    UAMI: 'uami-ssharer-k8s-deploy-${environmentName}'
    ENV: environmentName
    ROLE: 'AcrPull'
    federationTypes: 'environment'
  }
  paas: {
    UAMI: 'uami-ssharer-paas-${environmentName}'
    ENV: environmentName
    ROLE: 'contributor'
    federationTypes: 'environment'
  }
}

// =====================
// Role Definition IDs
// =====================

var AcrPullRoleDefinitionId = '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/7f951dda-4ed3-4680-a7ca-43fe172d538d' // AcrPull role definition ID
var ContributorRoleDefinitionId = '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c' // Contributor role definition ID

var roleIdMap = {
  contributor: ContributorRoleDefinitionId
  AcrPull: AcrPullRoleDefinitionId
}

// =====================
// Resource Groups
// =====================

// Reference existing hub resource group for shared artifacts
resource hubRG 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  name: sharedArtifactsResourceGroupName
}

// Create resource group for Kubernetes workloads
resource k8sRG 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-ssharer-k8s-spoke-${environmentName}'
  location: location
  tags: tags
}

// Create resource group for PaaS workloads
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

// =====================
// Managed Identities and Federated Credentials
// =====================

// Dynamically create UAMIs for each workload identity in the management resource group
module uamiModules 'common-modules/uami.bicep' = [for (item, i) in items(workloadIdentities): {
  name: 'deploy-uami-${item.key}'
  scope: managementRg
  params: {
    uamiLocation: location
    uamiNames: [item.value.UAMI]
    tags: tags
  }
}]

// Create Environment Federated Credentials for each UAMI if specified in federationTypes
module envFederationModules 'common-modules/github-federation.bicep' = [for (item, i) in items(workloadIdentities): if (contains(split(item.value.federationTypes, ','), 'environment')) {
  name: 'deploy-env-fed-${item.key}'
  scope: managementRg
  params: {
    UamiName: uamiModules[i].outputs.uamiNames[0]
    GitHubOrganizationName: gitHubOrganizationName
    GitHubRepositoryName: gitHubRepositoryName
    environmentName: item.value.ENV
    fedType: 'environment'
    federatedCredentialName: 'gh-env-${item.value.ENV}-${item.key}'
  }
  dependsOn: [uamiModules[i]]
}]

// Create Branch Federated Credentials for all workload identities that specify 'branch' in federationTypes
module branchFederationModules 'common-modules/github-federation.bicep' = [for (item, i) in items(workloadIdentities): if (contains(split(item.value.federationTypes, ','), 'branch')) {
  name: 'deploy-branch-fed-${item.key}'
  scope: managementRg
  params: {
    UamiName: uamiModules[i].outputs.uamiNames[0]
    GitHubOrganizationName: gitHubOrganizationName
    GitHubRepositoryName: gitHubRepositoryName
    branchName: 'main'
    fedType: 'branch'
    federatedCredentialName: 'gh-branch-main-${item.value.UAMI}'
  }
  dependsOn: [uamiModules[i], envFederationModules[i]]
}]

// =====================
// RBAC Assignments
// =====================

// Assign RBAC roles to UAMIs in k8sRG
module rbacAssignmentsK8s 'common-modules/uami-rbac.bicep' = [for (item, i) in items(workloadIdentities): if (contains(item.key, 'k8s')) {
  name: 'deploy-rbac-${item.key}'
  scope: k8sRG
  params: {
    uamiPrincipalId: uamiModules[i].outputs.uamiPrincipalIds[0]
    roleDefinitionId: roleIdMap[item.value.ROLE]
  }
  dependsOn: [uamiModules[i]]
}]

// Assign RBAC roles to UAMIs in paasRG
module rbacAssignmentsPaas 'common-modules/uami-rbac.bicep' = [for (item, i) in items(workloadIdentities): if (contains(item.key, 'paas')) {
  name: 'deploy-rbac-${item.key}'
  scope: paasRG
  params: {
    uamiPrincipalId: uamiModules[i].outputs.uamiPrincipalIds[0]
    roleDefinitionId: roleIdMap[item.value.ROLE]
  }
  dependsOn: [uamiModules[i]]
}]

// Assign RBAC roles to any other UAMIs in hubRG
module rbacAssignmentsHub 'common-modules/uami-rbac.bicep' = [for (item, i) in items(workloadIdentities): if (!contains(item.key, 'k8s') && !contains(item.key, 'paas')) {
  name: 'deploy-rbac-${item.key}'
  scope: hubRG
  params: {
    uamiPrincipalId: uamiModules[i].outputs.uamiPrincipalIds[0]
    roleDefinitionId: roleIdMap[item.value.ROLE]
  }
  dependsOn: [uamiModules[i]]
}]

// =====================
// Outputs
// =====================

output uamiNames array = [for (item, i) in items(workloadIdentities): uamiModules[i].outputs.uamiNames[0]] // All UAMI names
output uamiPrincipalIds array = [for (item, i) in items(workloadIdentities): uamiModules[i].outputs.uamiPrincipalIds[0]] // All UAMI principal IDs
output federatedCredentialNames array = [for (item, i) in items(workloadIdentities): {
  env: contains(split(item.value.federationTypes, ','), 'environment') ? envFederationModules[i].outputs.federatedCredentialName : null
  branch: contains(split(item.value.federationTypes, ','), 'branch') ? branchFederationModules[i].outputs.federatedCredentialName : null
}] // Federated credential names for each identity
output managementResourceGroupName string = managementRg.name // Management RG name
output hubResourceGroupName string = hubRG.name // Shared artifacts RG name
output k8sResourceGroupName string = k8sRG.name // K8s RG name
output paasResourceGroupName string = paasRG.name // PaaS RG name
output tenantId string = subscription().tenantId // Azure tenant ID
output subscriptionId string = subscription().subscriptionId // Azure subscription ID
output environmentName string = environmentName // Environment name