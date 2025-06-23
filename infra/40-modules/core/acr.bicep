// Azure Container Registry configuration
// Creates and configures ACR for container image storage
@description('Azure Container Registry name')
param acrName string

@description('Location for the ACR')
param location string

@description('SKU for the ACR')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param sku string = 'Standard'

@description('Tags for the ACR')
param tags object = {}

@description('Enable admin user for the ACR')
param enableAdminUser bool = false

@description('Enable encryption for the ACR')
param enableEncryption bool = false

@description('Key Vault resource ID for customer-managed encryption key (required if enableEncryption is true)')
param keyVaultResourceId string = ''

@description('Key name in Key Vault for encryption (required if enableEncryption is true)')
param keyName string = ''

@description('Enable data endpoint for the ACR')
param enableDataEndpoint bool = false

@description('Enable public network access for the ACR')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Enabled'

@description('Enable zone redundancy for Premium SKU')
param enableZoneRedundancy bool = false

@description('Network rule set for the ACR')
param networkRuleSet object = {
  defaultAction: 'Allow'
  ipRules: []
  virtualNetworkRules: []
}

@description('Enable anonymous pull access')
param enableAnonymousPull bool = false

@description('Enable dedicated data endpoints per region for geo-replication')
param enableDedicatedDataEndpoint bool = false

resource acr 'Microsoft.ContainerRegistry/registries@2025-04-01' = {
  name: acrName
  location: location
  tags: tags
  sku: {
    name: sku
  }
  properties: {
    adminUserEnabled: enableAdminUser
    dataEndpointEnabled: enableDataEndpoint || enableDedicatedDataEndpoint
    publicNetworkAccess: publicNetworkAccess
    networkRuleSet: networkRuleSet
    anonymousPullEnabled: enableAnonymousPull
    zoneRedundancy: (sku == 'Premium' && enableZoneRedundancy) ? 'Enabled' : 'Disabled'
    encryption: enableEncryption ? {
      status: 'enabled'
      keyVaultProperties: {
        keyIdentifier: '${keyVaultResourceId}/keys/${keyName}'
      }
    } : {
      status: 'disabled'
    }
  }
}

output acrId string = acr.id
output acrLoginServer string = acr.properties.loginServer
output acrName string = acr.name
