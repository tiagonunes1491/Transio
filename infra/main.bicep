targetScope = 'subscription'

@description('Location for the resource group')
param rgLocation string = 'spaincentral'

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
  location: rgLocation
  tags: tags
}
