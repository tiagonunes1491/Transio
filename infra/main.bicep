targetScope = 'subscription'

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
