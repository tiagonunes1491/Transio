using './main.bicep'

// Basic configuration
param resourceLocation = 'spaincentral'
param projectCode = 'ss'
param serviceCode = 'swa'
param environmentName = 'dev'

// Tagging configuration
param costCenter = '1000'
param createdBy = 'bicep-deployment-dev'
param owner = 'tiago-nunes'
param ownerEmail = 'tiago.nunes@microsoft.com'


// Existing infrastructure references
param acrName = 'ssdswaacr'
param cosmosDbAccountName = 'ss-d-swa-cosmos'
param keyVaultName = 'ssdswakv' // Note: In future deployments, this should be renamed to 'ssdswakv' to remove 'akv' reference

// Database configuration
param cosmosDatabaseName = 'swa-dev'
param cosmosContainerName = 'secrets'


param acaEnvironmentResourceGroupName = 'ss-d-swa-rg'
param acaEnvironmentName = 'ss-d-swa-cae'
// Application configuration
param containerImage = 'ssdswaacr.azurecr.io/secure-secret-sharer:dev'

// Key Vault secrets configuration (simplified approach with direct secret URIs)
param encryptionKeyUri = 'https://ssdswakv.vault.azure.net/secrets/encryption-key'
param encryptionKeyPreviousUri = 'https://ssdswakv.vault.azure.net/secrets/encryption-key' // Note: Update with specific version when using previous revision

// Environment variables (including non-sensitive configuration)
param environmentVariables = [  
  {
    name: 'ENVIRONMENT'
    value: 'development'
  }
  {
    name: 'LOG_LEVEL'
    value: 'DEBUG'
  }
  {
    name: 'SECRET_EXPIRY_HOURS'
    value: '24'
  }
  {
    name: 'USE_MANAGED_IDENTITY'
    value: 'true'
  }
  {
    name: 'MAX_SECRET_LENGTH_KB'
    value: '100'
  }
  {
    name: 'COSMOS_DATABASE_NAME'
    value: 'swa-dev'
  }
  {
    name: 'COSMOS_CONTAINER_NAME'
    value: 'secrets'
  }
  {
    name: 'COSMOS_ENDPOINT'
    value: 'https://ss-d-swa-cosmos.documents.azure.com:443/'
  }
]

// Container App ingress configuration
param useExternalIngress = true
