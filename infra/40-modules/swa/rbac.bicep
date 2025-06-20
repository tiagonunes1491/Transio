// RBAC role assignments for SWA/ACA platform services
// Configures access permissions for Key Vault, ACR, and Cosmos DB resources
@description('ID of the Azure Key Vault')
@minLength(1)
param keyVaultId string

@description('ID of the Azure Container Registry')
@minLength(1)
param acrId string

@description('UAMI Principal IDs array to give access to Key Vault and ACR')
param uamiId string 

@description('Shared Cosmos DB account ID for RBAC assignment')
param cosmosDbAccountId string = ''

var keyVaultSecretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'
var acrPullRoleId = '7f951dda-4ed3-4680-a7ca-43fe172d538d'
var networkContributorRoleId = '4d97b98b-1d4f-4787-a291-c67834d212e7'
var storageFileDataPrivilegedContributorRoleId = '69566ab7-960f-475b-8e7c-b3118f30c6bd'
var cosmosDbDataContributorRoleId = '00000000-0000-0000-0000-000000000002' // Cosmos DB Built-in Data Contributor
// Existing resources

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  scope: resourceGroup()
  name: split(keyVaultId, '/')[8]
}


resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  scope: resourceGroup()
  name: split(acrId, '/')[8]
}

// Reference to existing Cosmos DB account for RBAC assignment
resource cosmosDbAccount 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' existing = if (!empty(cosmosDbAccountId)) {
  scope: resourceGroup()
  name: split(cosmosDbAccountId, '/')[8]
}

resource kvRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
    scope: keyVault
    name: guid(keyVault.id, uamiId, 'KeyVaultSecretsUser')
    properties: {
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsUserRoleId)
      principalId: uamiId
      principalType: 'ServicePrincipal'
  }
}

// Make sure the principalId matches the Container App's managed identity
resource acrRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
    scope: acr
    name: guid(acr.id, uamiId, 'AcrPull')
    properties: {
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', acrPullRoleId)
      principalId: uamiId // This should be the Container App's managed identity principal ID
      principalType: 'ServicePrincipal'
  }
}


// Cosmos DB Data Contributor role assignment for managed identity
resource cosmosDbRoleAssignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2023-04-15' = if (!empty(cosmosDbAccountId)) {
  name: guid(cosmosDbAccount.id, uamiId, cosmosDbDataContributorRoleId)
  parent: cosmosDbAccount
  properties: {
    roleDefinitionId: '${cosmosDbAccount.id}/sqlRoleDefinitions/${cosmosDbDataContributorRoleId}'
    principalId: uamiId
    scope: cosmosDbAccount.id
  }
}

// Outputs
output acrRoleAssignmentId string = acrRoleAssignment.id
output keyVaultRoleAssignmentId string = kvRoleAssignment.id
output cosmosDbRoleAssignmentId string = !empty(cosmosDbAccountId) ? cosmosDbRoleAssignment.id : ''
