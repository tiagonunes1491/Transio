using 'main.bicep'

param resourceLocation  = 'spaincentral'
param rgName = 'rg-secure-secret-sharer-dev'
param tags  = {
  environment: 'dev'
  project: 'secure-secret-sharer'
  owner: 'Tiago'
}
param vnetName = 'vnet-secureSecretSharer'

param addressSpace  = [
  '10.0.0.0/16'
]

param subnets  = [
  {
    name: 'snet-aks'
    addressPrefix: '10.0.1.0/24'
  }
]
