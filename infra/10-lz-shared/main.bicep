// Shared Landing Zone Infrastructure for Secure Secret Sharer
// Provisions shared resource groups, managed identities, federated credentials, and RBAC for shared infrastructure
targetScope = 'subscription'

// Resource configuration
@description('Location for the resources')
param location string = 'spaincentral'

@description('Project code')
param projectCode string = 'ss'

@description('Service code for shared services')
param serviceCode string = 'hub'

// Tagging configuration
@description('Cost center for billing')
param costCenter string = '1000'

@description('Created by information')
param createdBy string = 'bicep-deployment'

@description('Owner')
param owner string = 'tiago-nunes'

@description('Owner email')
param ownerEmail string = 'tiago.nunes@example.com'

@description('Creation date for tagging')
param createdDate string = utcNow('yyyy-MM-dd')

// GitHub integration configuration
@description('GitHub organization name to federate with')
param gitHubOrganizationName string

@description('GitHub repository name to federate with')
param gitHubRepositoryName string

@description('GitHub workload identities for the shared resources infrastructure. Each entry defines a UAMI, its environment, RBAC role, and federation types.')
param workloadIdentities object = {
    creator: {
        UAMI: 'creator'
        ENV: 'shared-protected'
        ROLE: 'contributor'
        federationTypes: 'environment'
    }
    push: {
        UAMI: 'acr-push'
        ENV: 'shared'
        ROLE: 'AcrPush'
        federationTypes: 'environment'
    }
}

// =====================
// Naming and Tagging Variables (using standardized patterns)
// =====================

// Standard tags using the same pattern as the tagging module
var standardTags = {
  environment: 'shared'
  project: projectCode
  service: serviceCode
  costCenter: costCenter
  createdBy: createdBy
  owner: owner
  ownerEmail: ownerEmail
  createdDate: createdDate
  managedBy: 'bicep'
  deployment: deployment().name
}

// Environment mapping (consistent with naming module)
var envMapping = {
  dev: 'd'
  prod: 'p'
  shared: 's'
}

// Generate names using the same pattern as the naming module
var hubRgName = '${projectCode}-${envMapping.shared}-${serviceCode}-rg'
var mgmtRgName = '${projectCode}-${envMapping.shared}-mgmt-rg'


// =====================
// Role Definition IDs
// =====================

var ContributorRoleDefinitionId = '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c' // Contributor role definition ID
var AcrPushRoleDefinitionId = '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/8311e382-0749-4cb8-b61a-304f252e45ec' // AcrPush role definition ID

var roleIdMap = {
  contributor: ContributorRoleDefinitionId
  AcrPush: AcrPushRoleDefinitionId
}

// =====================
// Resource Groups
// =====================

// Create the shared artifacts resource group
resource hubRG 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: hubRgName
  location: location
  tags: standardTags
}

// Create the management resource group for shared infrastructure
resource mgmtSharedRG 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: mgmtRgName
  location: location
  tags: standardTags
}

// =====================
// Managed Identities and Federated Credentials
// =====================

// Use naming and tagging modules within the resource groups
module standardTagsModule '../40-modules/core/tagging.bicep' = {
  name: 'standard-tags'
  scope: mgmtSharedRG
  params: {
    environment: 'shared'
    project: projectCode
    service: serviceCode
    costCenter: costCenter
    createdBy: createdBy
    owner: owner
    ownerEmail: ownerEmail
    createdDate: createdDate
  }
}

// Generate UAMI names using naming modules within the resource group
module uamiNamingModules '../40-modules/core/naming.bicep' = [for item in items(workloadIdentities): {
  name: 'uami-naming-${item.key}'
  scope: mgmtSharedRG
  params: {
    projectCode: projectCode
    environment: 'shared'
    serviceCode: item.value.UAMI
    resourceType: 'id'
  }
}]

// Dynamically create UAMIs for each workload identity in the management resource group
module uamiModules '../40-modules/core/uami.bicep' = [for (item, i) in items(workloadIdentities): {
  name: 'deploy-uami-${item.key}'
  scope: mgmtSharedRG
  params: {
    uamiLocation: location
    uamiNames: [uamiNamingModules[i].outputs.resourceName]
    tags: standardTagsModule.outputs.tags
  }
  dependsOn: [uamiNamingModules[i]]
}]

// Create Environment Federated Credentials for each UAMI if specified in federationTypes
module envFederationModules '../40-modules/core/github-federation.bicep' = [for (item, i) in items(workloadIdentities): if (contains(split(item.value.federationTypes, ','), 'environment')) {
  name: 'deploy-env-fed-${item.key}'
  scope: mgmtSharedRG
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
module branchFederationModules '../40-modules/core/github-federation.bicep' = [for (item, i) in items(workloadIdentities): if (contains(split(item.value.federationTypes, ','), 'branch')) {
  name: 'deploy-branch-fed-${item.key}'
  scope: mgmtSharedRG
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

// Assign RBAC roles to all UAMIs in the shared artifacts resource group
module rbacAssignments '../40-modules/core/uami-rbac.bicep' = [for (item, i) in items(workloadIdentities): {
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
output managementResourceGroupName string = mgmtSharedRG.name // Management RG name
output artifactsResourceGroupName string = hubRG.name // Shared artifacts RG name
