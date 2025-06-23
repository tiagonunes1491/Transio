@description('ID of the Azure Key Vault (optional - set if Key Vault is in this RG)')
param keyVaultId string = ''

@description('Principal ID of the managed identity to give access to Key Vault, ACR, and Cosmos DB')
param id string

@description('Role definition ID for Key Vault Secrets User role')
param keyVaultSecretsUserRoleId string = '4633458b-17de-408a-b874-0445c86b69e6'

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  scope: resourceGroup()
  name: split(keyVaultId, '/')[8]
}

resource kvRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
    scope: keyVault
    name: guid(keyVaultId, id, 'KeyVaultSecretsUser')
    properties: {
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsUserRoleId)
      principalId: id
      principalType: 'ServicePrincipal'
  }
}


// Outputs
output keyVaultRoleAssignmentId string = kvRoleAssignment.id
