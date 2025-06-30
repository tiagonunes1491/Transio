// main.bicepparam

using 'main.bicep'

// Basic configuration
param resourceLocation = 'spaincentral'
param projectCode = 'ss'
param serviceCode = 'swa'
param environmentName = 'dev'

// Tagging configuration
param costCenter = '1000'
param createdBy = 'bicep-deployment'
param owner = 'tiago-nunes'
param ownerEmail = 'tiago.nunes@example.com'

// External Key Vault reference (created by bootstrap deployment)
param existingKeyVaultName = 'ss-dev-swa-kv'  // Platform-specific Key Vault
param existingKeyVaultResourceGroup = 'rg-ss-dev-swa'

// Azure Container Registry configuration
param acrSku = 'Premium'
param acrEnableAdminUser = false

// Cosmos DB configuration
param cosmosDbConfig = [
  {
    name: 'ssdb'
    containers: [
      {
        name: 'secrets'
        partitionKey: { paths: ['/link_id'], kind: 'Hash' }
        defaultTtl: 86400
        autoscaleSettings: { maxThroughput: 1000 }
      }
    ]
  }
]
param cosmosEnableFreeTier = false
