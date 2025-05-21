targetScope = 'subscription'

@description('The Azure AD tenant ID that should be used for authenticating requests to the key vault. Defaults to the current subscription tenant ID.')
param tenantId string = subscription().tenantId

@description('Location for the resources')
param resourceLocation string = 'spaincentral'

@description('Name of the resource group')
param rgName string = 'rg-secure-secret-sharer'

@description('Tags for the resources')
param tags object = {
  environment: 'dev'
  project: 'secure-secret-sharer'
  owner: 'Tiago'
}

resource rg 'Microsoft.Resources/resourceGroups@2025-03-01' = {
  name: rgName
  location: resourceLocation
  tags: tags
}

// Deployment for VNET

@description('Name of the virtual network')
param vnetName string = 'vnet-secureSecretSharer'

@description('Address space for the virtual network')
param addressSpace array = [
  '10.0.0.0/16'
]

@description('Subnets for the virtual network')
param subnets array = [
  {
    name: 'snet-aks'
    addressPrefix: '10.0.1.0/24'
  }
]

module network 'modules/network.bicep' = {
  name: 'network'
  scope: rg
  params: {
    vnetName: vnetName
    location: resourceLocation
    addressSpace: addressSpace
    subnets: subnets
  }
}

// Deployment for ACR

@description('Azure Container Registry name')
param acrName string

@description('SKU for the ACR')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param acrSku string = 'Standard'

@description('Enable admin user for the ACR')
param acrEnableAdminUser bool = false

module acr 'modules/acr.bicep' = {
  name: 'acr'
  scope: rg
  params: {
    acrName: acrName
    location: resourceLocation
    sku: acrSku
    enableAdminUser: acrEnableAdminUser
  }
}

// Deployment for AKV

@description('Name of the keyvault')
param akvName string = 'kv-secure-secret-sharer'

@description('SKU for the keyvault')
@allowed([
  'standard'
  'premium'
])
param akvSku string = 'standard'

@description('Enable rbac for the keyvault')
param akvRbac bool = true

@description('Enable soft delete for the keyvault')
param akvSoftDelete bool = true

@description('Enable purge protection for the keyvault')
param akvPurgeProtection bool = true

@description('Secure object for secrets')
@secure()
param akvSecrets object

module akv 'modules/keyvault.bicep' = {
  name: 'keyvault'
  scope: rg
  params: {
    keyvaultName: akvName
    location: resourceLocation
    tags: tags
    sku: akvSku
    tenantId: tenantId
    enableRbac: akvRbac
    enableSoftDelete: akvSoftDelete
    enablePurgeProtection: akvPurgeProtection
    secretsToSet: akvSecrets
  }
}
