targetScope = 'subscription'
param rgLocation string = 'spaincentral'
param rgName string = 'rg-secure-secret-sharer'

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
