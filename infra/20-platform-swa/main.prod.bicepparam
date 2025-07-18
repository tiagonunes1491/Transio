// main.bicepparam

using 'main.bicep'

// Basic configuration
param resourceLocation = 'spaincentral'
param projectCode = 'ts'
param serviceCode = 'swa'
param environmentName = 'prod'

// Tagging configuration
param costCenter = '1000'
param createdBy = 'bicep-deployment'
param owner = ''
param ownerEmail = ''

// External Key Vault reference (created by bootstrap deployment)
param existingKeyVaultName = 'tspswakv'  // Platform-specific Key Vault for prod

// Azure Container Registry configuration
param acrSku = 'Premium'
param acrEnableAdminUser = false

// Cosmos DB configuration
param cosmosDbConfig = [
  {
    name: 'tsdb'
    containers: [
      {
        name: 'secrets'
        partitionKey: { paths: ['/link_id'], kind: 'Hash' }
        defaultTtl: 86400
        autoscaleSettings: { maxThroughput: 4000 }
      }
    ]
  }
]
param cosmosEnableFreeTier = true
