// RBAC role assignments for SWA/ACA platform services
// Configures access permissions for Key Vault, ACR, and Cosmos DB resources
// This module can be called with different resource group scopes to handle cross-RG scenarios
//
// Usage for cross-resource group scenarios:
// 1. Call this module from the Key Vault resource group with only keyVaultId parameter set
// 2. Call this module from the ACR/CosmosDB resource group with acrId and cosmosDbAccountId parameters set
// 3. The module will automatically deploy only the relevant role assignments for resources in the current RG

@description('ID of the Azure Key Vault (optional - set if Key Vault is in this RG)')
param keyVaultId string = ''

@description('ID of the Azure Container Registry (optional - set if ACR is in this RG)')
param acrId string = ''

@description('Principal ID of the managed identity to give access to Key Vault, ACR, and Cosmos DB')
param id string

@description('Shared Cosmos DB account ID for RBAC assignment (optional - set if Cosmos DB is in this RG)')
param cosmosDbAccountId string = ''

@description('Cosmos DB database name to scope the RBAC assignment to')
param cosmosDatabaseName string = ''

@description('Deploy Key Vault role assignment (true if Key Vault is in this resource group)')
param deployKeyVaultRole bool = !empty(keyVaultId)

@description('Deploy ACR role assignment (true if ACR is in this resource group)')
param deployAcrRole bool = !empty(acrId)

@description('Deploy Cosmos DB role assignment (true if Cosmos DB is in this resource group)')
param deployCosmosDbRole bool = !empty(cosmosDbAccountId)

var keyVaultSecretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'
var acrPullRoleId = '7f951dda-4ed3-4680-a7ca-43fe172d538d'
// For Cosmos DB, we need to use the actual built-in role definition that exists in the Cosmos DB account
// The built-in Data Contributor role ID is a well-known GUID in Cosmos DB
var cosmosDbDataContributorRoleId = '00000000-0000-0000-0000-000000000002' // Cosmos DB Built-in Data Contributor

// Existing resources - conditionally declared based on which resources are in this RG

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' existing = if (deployKeyVaultRole) {
  scope: resourceGroup()
  name: split(keyVaultId, '/')[8]
}

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = if (deployAcrRole) {
  scope: resourceGroup()
  name: split(acrId, '/')[8]
}

// Reference to existing Cosmos DB account for RBAC assignment
resource cosmosDbAccount 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' existing = if (deployCosmosDbRole) {
  scope: resourceGroup()
  name: split(cosmosDbAccountId, '/')[8]
}

resource kvRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (deployKeyVaultRole) {
    scope: keyVault
    name: guid(keyVaultId, id, 'KeyVaultSecretsUser')
    properties: {
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsUserRoleId)
      principalId: id
      principalType: 'ServicePrincipal'
  }
}

// Make sure the principalId matches the Container App's managed identity
resource acrRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (deployAcrRole) {
    scope: acr
    name: guid(acrId, id, 'AcrPull')
    properties: {
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', acrPullRoleId)
      principalId: id // This should be the Container App's managed identity principal ID
      principalType: 'ServicePrincipal'
  }
}


// Cosmos DB Data Contributor role assignment for managed identity - scoped to database
resource cosmosDbRoleAssignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2023-04-15' = if (deployCosmosDbRole && !empty(cosmosDatabaseName)) {
  name: guid(cosmosDbAccountId, id, cosmosDbDataContributorRoleId)
  parent: cosmosDbAccount
  properties: {
    roleDefinitionId: '${cosmosDbAccount.id}/sqlRoleDefinitions/${cosmosDbDataContributorRoleId}'
    principalId: id
    scope: '${cosmosDbAccount.id}/dbs/${cosmosDatabaseName}'  // Scope to specific database
  }
}

// Outputs
output acrRoleAssignmentId string = deployAcrRole ? acrRoleAssignment.id : ''
output keyVaultRoleAssignmentId string = deployKeyVaultRole ? kvRoleAssignment.id : ''
output cosmosDbRoleAssignmentId string = (deployCosmosDbRole && !empty(cosmosDatabaseName)) ? cosmosDbRoleAssignment.id : ''
