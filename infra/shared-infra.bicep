// Parameters for shared infrastructure deployment

@description('Location for the resources')
param resourceLocation string = 'spaincentral'


@description('Tags for the resources')
param tags object = {
  environment: 'dev'
  project: 'secure-secret-sharer'
  owner: 'Tiago'
}

@description('Azure Container Registry name')
param acrName string

@description('SKU for the ACR')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param acrSku string = 'Premium'

@description('Enable admin user for the ACR')
param acrEnableAdminUser bool = false


module acr 'shared-infra-modules/acr.bicep' = {
  name: 'acr'
  params: {
    tags: tags
    acrName: acrName
    location: resourceLocation
    sku: acrSku
    enableAdminUser: acrEnableAdminUser
  }
}
