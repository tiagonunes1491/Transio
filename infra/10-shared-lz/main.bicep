// Module: 10-shared-lz/main.bicep
// Description: Shared Landing Zone Infrastructure for Secure Secret Sharer
// Provisions shared resource groups, managed identities, federated credentials, and RBAC for shared infrastructure.
// This template creates the foundational infrastructure for supporting workload identities with GitHub federation
// and appropriate RBAC assignments across shared resource groups.
//
// Parameters:
//   - location: Azure region for resource deployment (default: spaincentral)
//   - projectCode: Project identifier code (default: ss)
//   - serviceCode: Service identifier for shared services (default: plat)
//   - costCenter: Cost center for billing purposes
//   - createdBy, owner, ownerEmail: Resource ownership and tagging information
//   - gitHubOrganizationName: GitHub organization for federation
//   - gitHubRepositoryName: GitHub repository for federation
//   - workloadIdentities: Object defining UAMIs, their environments, roles, and federation types
//
// Resources Created:
//   - Resource Groups: Hub (shared artifacts) and management resource groups
//   - User Assigned Managed Identities (UAMIs): One for each workload identity
//   - Federated Credentials: GitHub environment-based federation for each UAMI
//   - RBAC Assignments: Role assignments for UAMIs in the hub resource group
//
// Outputs:
//   - uamiNames: Array of all created UAMI names
//   - uamiPrincipalIds: Array of all UAMI principal IDs
//   - federatedCredentialNames: Array of federated credential names for each identity
//   - managementResourceGroupName: Name of the management resource group
//   - artifactsResourceGroupName: Name of the hub/artifacts resource group
//
// Usage:
//   Deploy this template to establish the shared infrastructure foundation for the Secure Secret Sharer project.
//   Ensures proper naming conventions, tagging, and secure identity management for CI/CD workflows.
//
// Example:
//   az deployment sub create \
//     --location spaincentral \
//     --template-file main.bicep \
//     --parameters gitHubOrganizationName=myorg gitHubRepositoryName=myrepo
targetScope = 'subscription'

// Resource configuration
@description('Location for the resources')
param location string = 'spaincentral'

@description('Project code')
param projectCode string = 'ss'

@description('Service code for shared services')
param serviceCode string = 'plat'

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
        ENV: 'shared-protected'
        ROLE: 'contributor'
        federationTypes: 'environment'
    }
    push: {
        ENV: 'shared'
        ROLE: 'AcrPush'
        federationTypes: 'environment'
    }
}

// =====================
// Naming and Tagging Modules
// =====================

// Environment mapping (consistent with naming module)
var envMapping = {
  dev: 'd'
  prod: 'p'
  shared: 's'
}

// Generate RG names using consistent module for naming
module hubRgNamingModule '../40-modules/core/naming.bicep' = {
  name: 'rg-hub-naming'
  scope: subscription()
  params: {
    projectCode: projectCode
    environment: 'shared'
    serviceCode: serviceCode
    resourceType: 'rg'
  }
}



// Generate RG names using consistent naming pattern
// Exceptionally uses variable for RG creation because they no be compiled at runtime
var hubRgName = toLower('${projectCode}-${envMapping.shared}-${serviceCode}-rg')
var mgmtRgName = toLower('${projectCode}-i-mgmt-rg')

// Standard tags using consistent pattern
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


// =====================
// Role Definition IDs
// =====================

var roleIdMap = {
  contributor: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c' // Contributor role definition ID
  AcrPush: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/8311e382-0749-4cb8-b61a-304f252e45ec' // AcrPush role definition ID
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

// Generate UAMI names using naming modules at subscription scope
module uamiNamingModules '../40-modules/core/naming.bicep' = [for item in items(workloadIdentities): {
  name: 'uami-naming-${item.key}'
  scope: subscription()
  params: {
    projectCode: projectCode
    environment: 'shared'
    serviceCode: serviceCode
    resourceType: 'id'
    suffix: 'gh-${item.key}'
  }
}]

// Dynamically create UAMIs for each workload identity in the management resource group
module uamiModules '../40-modules/core/uami.bicep' = [for (item, i) in items(workloadIdentities): {
  name: 'deploy-uami-${item.key}'
  scope: mgmtSharedRG
  params: {
    uamiLocation: location
    uamiNames: [uamiNamingModules[i].outputs.resourceName]
    tags: standardTags
  }
  dependsOn: [uamiNamingModules[i]]
}]

// Create Environment Federated Credentials for each UAMI if specified in federationTypes
module envFederationModules '../40-modules/core/github-federation.bicep' = [for (item, i) in items(workloadIdentities): if (contains(split(item.value.federationTypes, ','), 'environment')) {
  name: 'deploy-env-fed-${item.key}'
  scope: mgmtSharedRG
  params: {
    UamiName: uamiModules[i].outputs.uamis[0].name
    GitHubOrganizationName: gitHubOrganizationName
    GitHubRepositoryName: gitHubRepositoryName
    environmentName: item.value.ENV
    fedType: 'environment'
    federatedCredentialName: 'fc-env-${item.value.ENV}-${item.key}'
  }
  dependsOn: [uamiModules[i]]
}]


// =====================
// RBAC Assignments
// =====================

// Assign RBAC roles to all UAMIs in the shared artifacts resource group
module rbacAssignments '../40-modules/core/roleAssignment.bicep' = [for (item, i) in items(workloadIdentities): {
  name: 'deploy-rbac-${item.key}'
  scope: hubRG
  params: {
    principalId: uamiModules[i].outputs.uamis[0].principalId
    roleDefinitionId: roleIdMap[item.value.ROLE]
  }
  dependsOn: [uamiModules[i]]
}]

// =====================
// Outputs
// =====================

output uamiNames array = [for (item, i) in items(workloadIdentities): uamiModules[i].outputs.uamis[0].name] // All UAMI names
output uamiPrincipalIds array = [for (item, i) in items(workloadIdentities): uamiModules[i].outputs.uamis[0].principalId] // All UAMI principal IDs
output federatedCredentialNames array = [for (item, i) in items(workloadIdentities): {
  env: contains(split(item.value.federationTypes, ','), 'environment') ? envFederationModules[i].outputs.federatedCredentialName : null
}] // Federated credential names for each identity
output managementResourceGroupName string = mgmtSharedRG.name // Management RG name
output artifactsResourceGroupName string = hubRG.name // Shared artifacts RG name
