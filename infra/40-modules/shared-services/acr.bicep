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

resource acr 'Microsoft.ContainerRegistry/registries@2025-04-01' = {
  name: acrName
  location: location
  tags: tags
  sku: {
    name: sku
  }
  properties: {
    adminUserEnabled: enableAdminUser
    dataEndpointEnabled: false
    encryption: {
      status: 'disabled'
    }
  }
}

output acrId string = acr.id
output acrLoginServer string = acr.properties.loginServer
output acrName string = acr.name
