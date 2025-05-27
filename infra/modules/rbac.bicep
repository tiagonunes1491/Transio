@description('ID of the Azure Key Vault')
@minLength(1)
param keyVaultId string

@description('ID of the Azure Container Registry')
@minLength(1)
param acrId string

@description('UAMI Principal IDs array to give access to Key Vault as secret user')
param uamiIds array = []

@description('ID of the Azure Kubernetes Service')
@minLength(1)
param aksId string

var keyVaultSecretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'
var acrPullRoleId = '7f951dda-4ed3-4680-a7ca-43fe172d538d'
// Existing resources

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  scope: resourceGroup()
  name: split(keyVaultId, '/')[8]
}

resource aks 'Microsoft.ContainerService/managedClusters@2023-10-01' existing = {
  scope: resourceGroup()
  name: split(aksId, '/')[8]
}

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  scope: resourceGroup()
  name: split(acrId, '/')[8]
}

// Assigns Key Vault Secrets User role to UAMIs for accessing secrets in Key Vault
resource kvRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for id in uamiIds: {
    scope: keyVault
    name: guid(keyVault.id, id, 'Key Vault Secrets User')
    properties: {
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsUserRoleId)
      principalId: id
      principalType: 'ServicePrincipal'

    }
  }
] 

// Assigns AcrPull role to AKS managed identity for pulling container images
resource acrRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
    scope: acr
    name: guid(acr.id, aks.id, 'AcrPull')
    properties: {
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', acrPullRoleId)
      principalId: aks.properties.identityProfile.kubeletidentity.objectId
      principalType: 'ServicePrincipal'
  }
}

output kvRoleAssignments array = [for i in range(0, length(uamiIds)): kvRoleAssignments[i].id]
output acrRoleAssignment object = {
  id: acrRoleAssignment.id
  principalId: aks.identity.principalId
}
