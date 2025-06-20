// landing-zone-k8s.bicep
// K8S Landing Zone Infrastructure for Secure Secret Sharer
// =====================================================
//
// This Bicep template creates K8S-specific landing zone infrastructure including:
// - K8S spoke resource group for hosting AKS and related resources
// - User-assigned managed identities for K8S workloads and deployments
// - GitHub federated credentials for CI/CD authentication
// - RBAC role assignments for managed identities
//
// Prerequisites:
// - Shared landing zone infrastructure must exist
// - GitHub repository configured for OIDC authentication
//
// Usage:
// az deployment sub create --location spaincentral --template-file main.bicep --parameters main.bicepparam
//

targetScope = 'subscription'

// =====================================================
// Parameters
// =====================================================

@description('Environment for the deployment (e.g., dev, prod)')
@allowed(['dev', 'prod'])
param environmentName string = 'dev'

@description('Azure region where resources will be deployed')
param location string = 'spaincentral'

@description('Project code')
param projectCode string = 'ss'

@description('Service code for K8S platform')
param serviceCode string = 'aks'

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

@description('GitHub organization name for federated credential setup')
param gitHubOrganizationName string

@description('GitHub repository name for federated credential setup')
param gitHubRepositoryName string

@description('K8S workload identities configuration with roles and federation settings')
param workloadIdentities object = {
  k8s: {
    UAMI: 'k8s'
    ENV: environmentName
    ROLE: 'contributor'
    federationTypes: 'environment'
  }
  k8sDeploy: {
    UAMI: 'k8s-deploy'
    ENV: environmentName
    ROLE: 'AcrPull'
    federationTypes: 'environment'
  }
}

// =====================================================
// Name Generation and Tagging
// =====================================================

// Environment mapping
var envMapping = {
  dev: 'd'
  prod: 'p'
  shared: 's'
}

// Standard tags
var standardTags = {
  environment: environmentName
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

// Generate resource names using naming convention
var hubRgName = '${projectCode}-${envMapping.shared}-hub-rg'
var k8sRgName = '${projectCode}-${envMapping[environmentName]}-${serviceCode}-rg'
var mgmtRgName = '${projectCode}-${envMapping[environmentName]}-mgmt-rg'

// Generate UAMI names
var uamiNames = [for item in items(workloadIdentities): '${projectCode}-${envMapping[environmentName]}-${item.value.UAMI}-id']

// =====================================================
// Variables
// =====================================================

// Azure built-in role definition IDs for RBAC assignments
var AcrPullRoleDefinitionId = '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/7f951dda-4ed3-4680-a7ca-43fe172d538d'
var ContributorRoleDefinitionId = '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'

// Role mapping for workload identities
var roleIdMap = {
  contributor: ContributorRoleDefinitionId
  AcrPull: AcrPullRoleDefinitionId
}

// =====================================================
// Existing Resources
// =====================================================

// Reference to existing shared artifacts resource group (created by shared landing zone)
resource hubRG 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  name: hubRgName
}

// =====================================================
// Resource Groups
// =====================================================

// K8S spoke resource group for AKS cluster and related resources
resource k8sRG 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: k8sRgName
  location: location
  tags: standardTags
}

// Management resource group for UAMIs and federated credentials
resource managementRg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: mgmtRgName
  location: location
  tags: standardTags
}

// =====================================================
// Managed Identities and Federated Credentials
// =====================================================

// Create user-assigned managed identities for each K8S workload
module uamiModules '../40-modules/core/uami.bicep' = [for (item, i) in items(workloadIdentities): {
  name: 'deploy-uami-${item.key}'
  scope: managementRg
  params: {
    uamiLocation: location
    uamiNames: [uamiNames[i]]
    tags: standardTags
  }
}]

// Create GitHub environment federated credentials for CI/CD authentication
module envFederationModules '../40-modules/core/github-federation.bicep' = [for (item, i) in items(workloadIdentities): if (contains(split(item.value.federationTypes, ','), 'environment')) {
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

// =====================================================
// RBAC Role Assignments
// =====================================================

// Assign appropriate roles to UAMIs in the K8S spoke resource group
module rbacAssignmentsK8s '../40-modules/core/uami-rbac.bicep' = [for (item, i) in items(workloadIdentities): {
  name: 'deploy-rbac-${item.key}'
  scope: k8sRG
  params: {
    uamiPrincipalId: uamiModules[i].outputs.uamiPrincipalIds[0]
    roleDefinitionId: roleIdMap[item.value.ROLE]
  }
  dependsOn: [uamiModules[i]]
}]

// =====================================================
// Outputs
// =====================================================

output uamiNames array = [for (item, i) in items(workloadIdentities): uamiModules[i].outputs.uamiNames[0]]
output uamiPrincipalIds array = [for (item, i) in items(workloadIdentities): uamiModules[i].outputs.uamiPrincipalIds[0]]
output federatedCredentialNames array = [for (item, i) in items(workloadIdentities): {
  env: contains(split(item.value.federationTypes, ','), 'environment') ? envFederationModules[i].outputs.federatedCredentialName : null
}]
output managementResourceGroupName string = managementRg.name
output hubResourceGroupName string = hubRG.name
output k8sResourceGroupName string = k8sRG.name
output tenantId string = subscription().tenantId
output subscriptionId string = subscription().subscriptionId
output environmentName string = environmentName
