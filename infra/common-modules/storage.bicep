@description('Storage account name')
param storageAccountName string

@description('Location for the storage account')
param location string

@description('Tags for the storage account')
param tags object = {}

@description('Storage account SKU')
param sku string = 'Standard_LRS'

@description('Storage account kind')
param kind string = 'StorageV2'

@description('VNet ID for VNet rules (optional)')
param vnetId string = ''

@description('ACA subnet ID for VNet rules (optional)')
param acaSubnetId string = ''

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: sku
  }
  kind: kind
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    networkAcls: {
      // Use secure deny-by-default with explicit VNet rules when VNet info is provided
      defaultAction: !empty(vnetId) && !empty(acaSubnetId) ? 'Deny' : 'Allow'
      bypass: 'AzureServices'
      ipRules: []
      virtualNetworkRules: !empty(vnetId) && !empty(acaSubnetId) ? [
        {
          id: acaSubnetId
          action: 'Allow'
        }
      ] : []
    }
  }
}

output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name
