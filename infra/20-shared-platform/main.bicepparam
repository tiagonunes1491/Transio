using 'main.bicep'

// Location for the resources
param resourceLocation = 'spaincentral'

// Environment configuration
param environment = 'shared'

// Project and service identification
param projectCode = 'ss'
param serviceCode = 'plat'

// Tagging information
param costCenter = '1000'
param createdBy = 'bicep-deployment'
param owner = 'tiago-nunes'
param ownerEmail = 'tiago.nunes@example.com'

// Azure Container Registry configuration
param acrSku = 'Premium'
param acrEnableAdminUser = false

// Cosmos DB configuration
param cosmosDatabaseNames = ['swa-dev', 'swa-prod', 'aks-dev', 'aks-prod']
param cosmosContainerName = 'secret'
param cosmosEnableFreeTier = false
param cosmosThroughput = 1000  // Minimum for autoscale
