//  The Orchestrator for landing zone deployment for Secure Sharer shared resources
targetScope = 'subscription'

@description('Location for the resources')
param location string = 'spaincentral' // Default location, can be overridden

@description('Name of the management resource group')
param managementResourceGroupName string = 'rg-ssharer-mgmt-shared'

@description('Tags for resources')
param tags object = {
  Application: 'Secure Sharer'
  environment: 'shared'
}

@description('GitHub organization name to federate with')
param gitHubOrganizationName string

@description('GitHub repository name to federate with')
param gitHubRepositoryName string

@description('GitHub workload identities for the shared resources infrastructure')
param workloadIdentities object = {
    creator: {
        UAMI: 'uami-ssharer-shared-infra-creator'
        ENV: 'shared-infra'
        ROLE: 'contributor'
        federationTypes: 'branch,environment'
    }
    push: {
        UAMI: 'uami-ssharer-acr-push'
        ENV: 'shared-artifacts'
        ROLE: 'AcrPush'
        federationTypes: 'environment'
    }
}

// Variables for the role definition IDs
var ContributorRoleDefinitionId = '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c' // Contributor role definition ID
var AcrPushRoleDefinitionId = '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/8311e382-0749-4cb8-b61a-304f252e45ec' // AcrPush role definition ID

var roleIdMap = {
  contributor: ContributorRoleDefinitionId
  AcrPush: AcrPushRoleDefinitionId
}

// Create the management resource group

resource hubRG 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-ssharer-artifacts-hub'
  location: location
  tags: {
    Application: 'Secure Sharer'
    environment: 'Shared Artifacts'
  }
}

// Create the artifact resource group

resource mgmtSharedRG 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: managementResourceGroupName
  location: location
  tags: {
    Application: 'Secure Sharer'
    environment: 'Shared Management'
  }
}

// Dynamically create UAMIs for each workload identity
module uamiModules 'common-modules/uami.bicep' = [for (item, i) in items(workloadIdentities): {
  name: 'deploy-uami-${item.key}'
  scope: mgmtSharedRG
  params: {
    uamiLocation: location
    uamiNames: [item.value.UAMI]
    tags: tags
  }
}]

// Create Environment Federated Credentials for each UAMI
module envFederationModules 'common-modules/github-federation.bicep' = [for (item, i) in items(workloadIdentities): if (contains(split(item.value.federationTypes, ','), 'environment')) {
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
module branchFederationModules 'common-modules/github-federation.bicep' = [for (item, i) in items(workloadIdentities): if (contains(split(item.value.federationTypes, ','), 'branch')) {
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

// Assign RBAC roles to all UAMIs in hubRG
module rbacAssignments 'common-modules/uami-rbac.bicep' = [for (item, i) in items(workloadIdentities): {
  name: 'deploy-rbac-${item.key}'
  scope: hubRG
  params: {
    uamiPrincipalId: uamiModules[i].outputs.uamiPrincipalIds[0]
    roleDefinitionId: roleIdMap[item.value.ROLE]
  }
  dependsOn: [uamiModules[i]]
}]

output uamiNames array = [for (item, i) in items(workloadIdentities): uamiModules[i].outputs.uamiNames[0]]
output uamiPrincipalIds array = [for (item, i) in items(workloadIdentities): uamiModules[i].outputs.uamiPrincipalIds[0]]
output federatedCredentialNames array = [for (item, i) in items(workloadIdentities): {
  env: contains(split(item.value.federationTypes, ','), 'environment') ? envFederationModules[i].outputs.federatedCredentialName : null
  branch: contains(split(item.value.federationTypes, ','), 'branch') ? branchFederationModules[i].outputs.federatedCredentialName : null
}]
output managementResourceGroupName string = mgmtSharedRG.name
output artifactsResourceGroupName string = hubRG.name
