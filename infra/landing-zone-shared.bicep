//  The Orchestrator for landing zone deployment for Secure Sharer shared resources
// Provisions shared resource groups, managed identities, federated credentials, and RBAC for shared infrastructure.
targetScope = 'subscription'

// =====================
// Parameters
// =====================

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

@description('GitHub workload identities for the shared resources infrastructure. Each entry defines a UAMI, its environment, RBAC role, and federation types.')
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

@description('Custom Reader with What-If Role Definition GUID (for use with custom RBAC roles)')
param ReaderWhatIfRoleDefinitionGuid string = '<REPLACE_WITH_YOUR_CUSTOM_ROLE_ID>'

@description('Name of the Cosmos DB account')
param cosmosDbAccountName string = 'cosmos-sharer-shared'

@description('The name of the database to create')
param cosmosDatabaseName string = 'SecureSharer'

@description('The name of the container to create')
param cosmosContainerName string = 'secrets'

@description('Principal IDs of managed identities that need access to Cosmos DB')
param managedIdentityPrincipalIds array = []

// =====================
// Role Definition IDs
// =====================

var ContributorRoleDefinitionId = '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c' // Contributor role definition ID
var AcrPushRoleDefinitionId = '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/8311e382-0749-4cb8-b61a-304f252e45ec' // AcrPush role definition ID
var ReaderWhatIfRoleDefinitionId = '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/${ReaderWhatIfRoleDefinitionGuid}' // What-If Reader role definition ID

var roleIdMap = {
  contributor: ContributorRoleDefinitionId
  AcrPush: AcrPushRoleDefinitionId
  readerWithWhatIf: ReaderWhatIfRoleDefinitionId
}

// =====================
// Resource Groups
// =====================

// Create the shared artifacts resource group
resource hubRG 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-ssharer-artifacts-hub'
  location: location
  tags: {
    Application: 'Secure Sharer'
    environment: 'Shared Artifacts'
  }
}

// Create the management resource group for shared infrastructure
resource mgmtSharedRG 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: managementResourceGroupName
  location: location
  tags: {
    Application: 'Secure Sharer'
    environment: 'Shared Management'
  }
}

// =====================
// Managed Identities and Federated Credentials
// =====================

// Dynamically create UAMIs for each workload identity in the management resource group
module uamiModules 'common-modules/uami.bicep' = [for (item, i) in items(workloadIdentities): {
  name: 'deploy-uami-${item.key}'
  scope: mgmtSharedRG
  params: {
    uamiLocation: location
    uamiNames: [item.value.UAMI]
    tags: tags
  }
}]

// Create Environment Federated Credentials for each UAMI if specified in federationTypes
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

// =====================
// RBAC Assignments
// =====================

// Assign RBAC roles to all UAMIs in the shared artifacts resource group
module rbacAssignments 'common-modules/uami-rbac.bicep' = [for (item, i) in items(workloadIdentities): {
  name: 'deploy-rbac-${item.key}'
  scope: hubRG
  params: {
    uamiPrincipalId: uamiModules[i].outputs.uamiPrincipalIds[0]
    roleDefinitionId: roleIdMap[item.value.ROLE]
  }
  dependsOn: [uamiModules[i]]
}]

// =====================
// Shared Infrastructure
// =====================

// Deploy Cosmos DB for shared use across K8S and SWA deployments
module cosmosDb 'shared-infra-modules/cosmos-db.bicep' = {
  name: 'deploy-cosmos-db'
  scope: hubRG
  params: {
    cosmosDbAccountName: cosmosDbAccountName
    location: location
    databaseName: cosmosDatabaseName
    containerName: cosmosContainerName
    tags: tags
    defaultTtl: 86400 // 24 hours TTL
    managedIdentityPrincipalIds: managedIdentityPrincipalIds
  }
}

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
output cosmosDbEndpoint string = cosmosDb.outputs.cosmosDbEndpoint // Cosmos DB endpoint
output cosmosDbAccountName string = cosmosDb.outputs.cosmosDbAccountName // Cosmos DB account name
output cosmosDatabaseName string = cosmosDb.outputs.databaseName // Cosmos DB database name
output cosmosContainerName string = cosmosDb.outputs.containerName // Cosmos DB container name
