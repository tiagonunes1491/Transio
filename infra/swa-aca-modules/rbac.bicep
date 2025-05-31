@description('ID of the Azure Key Vault')
@minLength(1)
param keyVaultId string

@description('ID of the Azure Container Registry')
@minLength(1)
param acrId string

@description('SAMI Principal IDs array to give access to Key Vault and ACR')
param samiId string 

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
    name: guid(keyVault.id, samiId, 'KeyVaultSecretsUser')
    properties: {
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsUserRoleId)
      principalId: samiId
      principalType: 'ServicePrincipal'
  }
}

// Assigns AcrPull role to AKS managed identity for pulling container images
resource acrRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
    scope: acr
    name: guid(acr.id, samiId, 'AcrPull')
    properties: {
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', acrPullRoleId)
      principalId: samiId
      principalType: 'ServicePrincipal'
  }
}

// Outputs
output acrRoleAssignmentId string = acrRoleAssignment.id
output keyVaultRoleAssignmentId string = kvRoleAssignment.id
