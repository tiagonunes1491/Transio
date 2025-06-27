// main.bicepparam

using 'mainv2.bicep'

// Basic configuration
param resourceLocation = 'spaincentral'
param projectCode = 'ss'
param serviceCode = 'aks'
param environmentName = 'dev'

// Tagging configuration
param costCenter = '1000'
param createdBy = 'bicep-deployment'
param owner = 'tiago-nunes'
param ownerEmail = 'tiago.nunes@example.com'

// Key Vault configuration
param akvSku = 'standard'
param akvRbac = true
param akvPurgeProtection = false
param akvSecrets = {
  'cosmos-endpoint': {
    value: 'https://ss-d-aks-cosmos.documents.azure.com:443/'
    contentType: 'uri'
    expires: 1782585600
  }
  'encryption-key': {
    value: '=fF3jdnJGZiQWSTrGD9kM2I5_7oP8qRsT6uVwXyZaBcE='
    contentType: 'base64'
    expires: 1782585600
  }
  'cosmos-database-name': {
    value: 'aks-dev'
    contentType: 'string'
    expires: 1782585600
  }
  'cosmos-container-name': {
    value: 'secrets'
    contentType: 'string'
    expires: 1782585600
  }
}

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
param federationConfigs = [
  {
    uamiTargetName: 'uami-securesharer-backend-dev' 
    k8sServiceAccountName: 'secret-sharer-backend-sa'
    k8sNamespace: 'default' 
  }
]
param appGwSku = 'WAF_v2'
