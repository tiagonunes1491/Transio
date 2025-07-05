// main.bicepparam

using 'main.bicep'

// Basic configuration
param resourceLocation = 'spaincentral'
param projectCode = 'ss'
param serviceCode = 'aks'
param environmentName = 'dev'

// Tagging configuration
param costCenter = '1000'
param createdBy = 'bicep-deployment'
param owner = ''
param ownerEmail = ''

// External Key Vault reference (created by bootstrap deployment)
param existingKeyVaultName = 'ssdakskv'  // Platform-specific Key Vault
param existingKeyVaultResourceGroup = 'ss-d-aks-rg'

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

// AKS cluster configuration
param kubernetesVersion = '1.31.7'
param systemNodePoolVmSize = 'Standard_D8ds_v5'
param userNodePoolVmSize = 'Standard_D8ds_v5'
param aksAdminGroupObjectIds = [
  '881fa64b-3783-4880-8920-0d297899074c'
]

// Federated identity configuration
// This order is important, as the array will be used to pass configurations across the module.
// First object is for backend and second for database.

param appGwSku = 'WAF_v2'
