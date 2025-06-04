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

@description('ID of the Azure Application Gateway for AGIC role assignments')
param applicationGatewayId string = ''

@description('AGIC managed identity object ID for role assignments')
param agicIdentityId string = ''

var keyVaultSecretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'
var acrPullRoleId = '7f951dda-4ed3-4680-a7ca-43fe172d538d'
var contributorRoleId = 'b24988ac-6180-42a0-ab88-20f7382dd24c'
var readerRoleId = 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
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

// Reference to Application Gateway (conditionally created when AGIC is enabled)
resource appGw 'Microsoft.Network/applicationGateways@2023-05-01' existing = if (!empty(applicationGatewayId)) {
  scope: resourceGroup()
  name: split(applicationGatewayId, '/')[8]
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

// AGIC role assignments (when Application Gateway is provided)
// Note: AGIC managed identity ID is passed as a parameter from the AKS module output

// Assigns Contributor role to AGIC managed identity on the Application Gateway
resource agicAppGwContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(applicationGatewayId) && !empty(agicIdentityId)) {
  scope: appGw
  name: guid(applicationGatewayId, agicIdentityId, 'AGICContributor')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', contributorRoleId)
    principalId: agicIdentityId
    principalType: 'ServicePrincipal'
  }
}

// Assigns Reader role to AGIC managed identity on the resource group
resource agicResourceGroupReaderRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(applicationGatewayId) && !empty(agicIdentityId)) {
  scope: resourceGroup()
  name: guid(resourceGroup().id, agicIdentityId, 'AGICReader')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', readerRoleId)
    principalId: agicIdentityId
    principalType: 'ServicePrincipal'
  }
}

output kvRoleAssignments array = [for i in range(0, length(uamiIds)): kvRoleAssignments[i].id]
output acrRoleAssignment object = {
  id: acrRoleAssignment.id
  principalId: aks.identity.principalId
}
output agicRoleAssignments object = !empty(applicationGatewayId) && !empty(agicIdentityId) ? {
  appGwContributor: agicAppGwContributorRoleAssignment.id
  resourceGroupReader: agicResourceGroupReaderRoleAssignment.id
  agicPrincipalId: agicIdentityId
} : {}
