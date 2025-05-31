@description('ID of the Azure Key Vault')
@minLength(1)
param keyVaultId string

@description('ID of the Azure Container Registry')
@minLength(1)
param acrId string

@description('UAMI Principal IDs array to give access to Key Vault and ACR')
param uamiId string 

var keyVaultSecretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'
var acrPullRoleId = '7f951dda-4ed3-4680-a7ca-43fe172d538d'
// Existing resources

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  scope: resourceGroup()
  name: split(keyVaultId, '/')[8]
}


resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  scope: resourceGroup()
  name: split(acrId, '/')[8]
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

// Outputs
output acrRoleAssignmentId string = acrRoleAssignment.id
output keyVaultRoleAssignmentId string = kvRoleAssignment.id
