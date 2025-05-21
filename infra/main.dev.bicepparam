// This file is used to deploy the main.bicep file in the dev environment
using 'main.bicep'

// Parameters for deployment scope
param resourceLocation  = 'spaincentral'
param rgName = 'rg-secure-secret-sharer-dev'
param tags  = {
  environment: 'dev'
  project: 'secure-secret-sharer'
  owner: 'Tiago'
}

// Parameters for the vnet
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

// Parameters for the ACR
param acrName = 'acrsecuresecretsharerdev'

param acrSku = 'Standard'

param acrEnableAdminUser = false
