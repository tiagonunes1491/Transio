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

@description('ID of the Azure Application Gateway that AGIC will use')
@minLength(1)
param appGwId  string

@description('ID of the Azure Virtual Network')
@minLength(1)
param vnetId string

@description('Shared Cosmos DB account ID for RBAC assignment')
param cosmosDbAccountId string = ''

// VAR for role IDs

var keyVaultSecretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'
var acrPullRoleId = '7f951dda-4ed3-4680-a7ca-43fe172d538d'
var contributorRoleId = 'b24988ac-6180-42a0-ab88-20f7382dd24c'
var readerRoleId = 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
var networkContributorRoleId = '4d97b98b-1d4f-4787-a291-c67834d212e7'
var cosmosDbDataContributorRoleId = '00000000-0000-0000-0000-000000000002' // Cosmos DB Built-in Data Contributor

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

resource AppGw 'Microsoft.Network/applicationGateways@2023-05-01' existing = {
  scope: resourceGroup()
  name: split(appGwId, '/')[8]
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' existing = {
  scope: resourceGroup()
  name: split(vnetId, '/')[8]
}

// Reference to existing Cosmos DB account for RBAC assignment
resource cosmosDbAccount 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' existing = if (!empty(cosmosDbAccountId)) {
  scope: resourceGroup()
  name: split(cosmosDbAccountId, '/')[8]
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

// AGIC Role Assignments - Following Azure best practices for least privilege
// Note: AGIC uses the ingressApplicationGateway addon identity

// Reader role at resource group level for AGIC to read resource metadata
resource agicToRgReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, aks.id, readerRoleId, 'agic-reader')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', readerRoleId)
    principalId: aks.properties.addonProfiles.ingressApplicationGateway.identity.objectId
    principalType: 'ServicePrincipal'
  }
}

// Contributor role on Application Gateway for AGIC to manage gateway configuration
resource agicToAppGwContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: AppGw
  name: guid(AppGw.id, aks.id, contributorRoleId, 'agic-appgw')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', contributorRoleId)
    principalId: aks.properties.addonProfiles.ingressApplicationGateway.identity.objectId
    principalType: 'ServicePrincipal'
  }
}

// Network Contributor role on VNet for AGIC to manage network resources
resource agicToVnetNetworkContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: vnet
  name: guid(vnet.id, aks.id, networkContributorRoleId, 'agic-vnet')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', networkContributorRoleId)
    principalId: aks.properties.addonProfiles.ingressApplicationGateway.identity.objectId
    principalType: 'ServicePrincipal'
  }
}

// Additional Contributor role for AKS cluster system-assigned identity on Application Gateway
// This addresses scenarios where AGIC uses the cluster's system identity for some operations
resource aksClusterToAppGwContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: AppGw
  name: guid(AppGw.id, aks.id, contributorRoleId, 'aks-cluster-appgw')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', contributorRoleId)
    principalId: aks.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Cosmos DB Data Contributor role assignments for UAMIs
resource cosmosDbRoleAssignments 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2023-04-15' = [for (id, i) in uamiIds: if (!empty(cosmosDbAccountId)) {
  name: guid(cosmosDbAccount.id, id, cosmosDbDataContributorRoleId, string(i))
  parent: cosmosDbAccount
  properties: {
    roleDefinitionId: '${cosmosDbAccount.id}/sqlRoleDefinitions/${cosmosDbDataContributorRoleId}'
    principalId: id
    scope: cosmosDbAccount.id
  }
}]

output kvRoleAssignments array = [for i in range(0, length(uamiIds)): kvRoleAssignments[i].id]
output acrRoleAssignment object = {
  id: acrRoleAssignment.id
  principalId: aks.identity.principalId
}
output agicRoleAssignments object = {
  readerRoleAssignmentId: agicToRgReader.id
  appGwContributorRoleAssignmentId: agicToAppGwContributor.id
  vnetNetworkContributorRoleAssignmentId: agicToVnetNetworkContributor.id
  aksClusterToAppGwContributorRoleAssignmentId: aksClusterToAppGwContributor.id
}
output cosmosDbRoleAssignments array = [for i in range(0, length(uamiIds)): !empty(cosmosDbAccountId) ? cosmosDbRoleAssignments[i].id : '']
