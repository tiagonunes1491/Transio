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
      defaultAction: 'Allow'
    }
  }
}

output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name
