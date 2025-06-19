using 'main.bicep'

// Location for the resources
param resourceLocation = 'spaincentral'

// Tags for the resources
param tags = {
  environment: 'dev'
  project: 'secure-sharer'
  owner: 'Tiago'
}

// Azure Container Registry configuration
param acrName = 'acrSecureSharer'
param acrSku = 'Premium'
param acrEnableAdminUser = false

// Cosmos DB configuration
param cosmosDbAccountName = 'cosmos-secsharer'
param cosmosDatabaseNames = ['paas-dev', 'paas-prod', 'aks-dev', 'aks-prod']
param cosmosContainerName = 'secret'
