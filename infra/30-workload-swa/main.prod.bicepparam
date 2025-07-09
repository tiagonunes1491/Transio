using './main.bicep'

// Basic configuration
param resourceLocation = 'spaincentral'
param projectCode = 'ts'
param serviceCode = 'swa'
param environmentName = 'prod'

// Tagging configuration
param costCenter = '1000'
param createdBy = 'bicep-deployment-prod'
param owner = ''
param ownerEmail = ''


// Existing infrastructure references
param acrName = 'sspswaacrr'
param cosmosDbAccountName = 'ss-p-swa-cosmos'
param keyVaultName = 'tspswakv' // Production Key Vault

// Database configuration
param cosmosDatabaseName = 'prod-swa'
param cosmosContainerName = 'secrets'


param acaEnvironmentResourceGroupName = 'ss-p-swa-rg'
param acaEnvironmentName = 'ss-p-swa-cae'
// Application configuration
param containerImage = 'sspswaacrr.azurecr.io/secure-secret-sharer:prod'

// Key Vault secrets configuration (simplified approach with direct secret URIs)
param encryptionKeyUri = 'https://tspswakv.vault.azure.net/secrets/encryption-key'
param encryptionKeyPreviousUri = 'https://tspswakv.vault.azure.net/secrets/encryption-key' // Note: Update with specific version when using previous revision

// Environment variables (including non-sensitive configuration)
param environmentVariables = [  
  {
    name: 'ENVIRONMENT'
    value: 'production'
  }
  {
    name: 'LOG_LEVEL'
    value: 'INFO'
  }
  {
    name: 'SECRET_EXPIRY_HOURS'
    value: '12'
  }
  {
    name: 'USE_MANAGED_IDENTITY'
    value: 'true'
  }
  {
    name: 'MAX_SECRET_LENGTH_KB'
    value: '50'
  }
  {
    name: 'COSMOS_DATABASE_NAME'
    value: 'prod-swa'
  }
  {
    name: 'COSMOS_CONTAINER_NAME'
    value: 'secrets'
  }
  {
    name: 'COSMOS_ENDPOINT'
    value: 'https://ss-p-swa-cosmos.documents.azure.com:443/'
  }
]

// Container App ingress configuration
param useExternalIngress = true
