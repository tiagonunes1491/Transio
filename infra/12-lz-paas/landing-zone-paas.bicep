// landing-zone-paas.bicep
// PaaS Landing Zone Infrastructure for Secure Secret Sharer
// ========================================================
//
// This Bicep template creates PaaS-specific landing zone infrastructure including:
// - PaaS spoke resource group for hosting Container Apps, Static Web Apps, etc.
// - User-assigned managed identities for PaaS workloads
// - GitHub federated credentials for CI/CD authentication
// - RBAC role assignments for managed identities
//
// Prerequisites:
// - Shared landing zone infrastructure must exist (rg-ssharer-artifacts-hub)
// - GitHub repository configured for OIDC authentication
//
// Usage:
// az deployment sub create --location spaincentral --template-file landing-zone-paas.bicep --parameters landing-zone-paas.bicepparam
//
targetScope = 'subscription'

// ========================================================
// Parameters
// ========================================================

@description('Environment for the deployment (e.g., dev, staging, prod)')
param environmentName string = 'dev'

@description('Azure region where resources will be deployed')
param location string = 'spaincentral'

@description('Name of the management resource group for UAMIs and federated credentials')
param managementResourceGroupName string = 'rg-ssharer-mgmt-${environmentName}'

@description('Resource tags applied to all created resources')
param tags object = {
  Application: 'Secure Sharer'
  environment: environmentName
}

@description('GitHub organization name for federated credential setup')
param gitHubOrganizationName string

@description('GitHub repository name for federated credential setup')
param gitHubRepositoryName string

@description('Shared artifacts resource group name (must exist from shared landing zone)')
param sharedArtifactsResourceGroupName string = 'rg-ssharer-artifacts-hub'

@description('PaaS workload identities configuration with roles and federation settings')
param workloadIdentities object = {
  paas: {
    UAMI: 'uami-ssharer-paas-${environmentName}'
    ENV: environmentName
    ROLE: 'contributor'
    federationTypes: 'environment'
  }
}

// ========================================================
// Variables
// ========================================================

// Azure built-in role definition ID for RBAC assignments
var ContributorRoleDefinitionId = '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'

// Role mapping for workload identities
var roleIdMap = {
  contributor: ContributorRoleDefinitionId
}

// ========================================================
// Existing Resources
// ========================================================

// Reference to existing shared artifacts resource group (created by shared landing zone)
resource hubRG 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  name: sharedArtifactsResourceGroupName
}

// ========================================================
// Resource Groups
// ========================================================

// PaaS spoke resource group for Container Apps, Static Web Apps, and related resources
resource paasRG 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-ssharer-paas-spoke-${environmentName}'
  location: location
  tags: tags
}

// Management resource group for UAMIs and federated credentials
resource managementRg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: managementResourceGroupName
  location: location
  tags: {
    Application: 'Secure Sharer'
    environment: environmentName
    purpose: 'management'
  }
}

// ========================================================
// Managed Identities and Federated Credentials
// ========================================================

// Create user-assigned managed identities for each PaaS workload
module uamiModules 'common-modules/uami.bicep' = [for (item, i) in items(workloadIdentities): {
  name: 'deploy-uami-${item.key}'
  scope: managementRg
  params: {
    uamiLocation: location
    uamiNames: [item.value.UAMI]
    tags: tags
  }
}]

// Create GitHub environment federated credentials for CI/CD authentication
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

// ========================================================
// RBAC Role Assignments
// ========================================================

// Assign appropriate roles to UAMIs in the PaaS spoke resource group
module rbacAssignmentsPaas 'common-modules/uami-rbac.bicep' = [for (item, i) in items(workloadIdentities): {
  name: 'deploy-rbac-${item.key}'
  scope: paasRG
  params: {
    uamiPrincipalId: uamiModules[i].outputs.uamiPrincipalIds[0]
    roleDefinitionId: roleIdMap[item.value.ROLE]
  }
  dependsOn: [uamiModules[i]]
}]

// ========================================================
// Outputs
// ========================================================

output uamiNames array = [for (item, i) in items(workloadIdentities): uamiModules[i].outputs.uamiNames[0]]
output uamiPrincipalIds array = [for (item, i) in items(workloadIdentities): uamiModules[i].outputs.uamiPrincipalIds[0]]
output federatedCredentialNames array = [for (item, i) in items(workloadIdentities): {
  env: contains(split(item.value.federationTypes, ','), 'environment') ? envFederationModules[i].outputs.federatedCredentialName : null
}]
output managementResourceGroupName string = managementRg.name
output hubResourceGroupName string = hubRG.name
output paasResourceGroupName string = paasRG.name
output tenantId string = subscription().tenantId
output subscriptionId string = subscription().subscriptionId
output environmentName string = environmentName
