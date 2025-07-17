using './main.bicep'

// Basic configuration
param resourceLocation = 'spaincentral'
param projectCode = 'ts'
param serviceCode = 'swa'
param environmentName = 'dev'

// Tagging configuration
param costCenter = '1000'
param createdBy = 'bicep-deployment-dev'
param owner = ''
param ownerEmail = ''


// Existing infrastructure references
param acrName = 'ssdswaacr'
param cosmosDbAccountName = 'ts-d-swa-cosmos'
param keyVaultName = 'tsdswakv' // Note: In future deployments, this should be renamed to 'tsdswakv' to remove 'akv' reference

// Database configuration
param cosmosDatabaseName = 'dev-swa'
param cosmosContainerName = 'secrets'


param acaEnvironmentResourceGroupName = 'ts-d-swa-rg'
param acaEnvironmentName = 'ts-d-swa-cae'
// Application configuration
param containerImage = 'ssdswaacr.azurecr.io/secure-secret-sharer:dev'

// Key Vault secrets configuration (simplified approach with direct secret URIs)
param encryptionKeyUri = 'https://tsdswakv.vault.azure.net/secrets/encryption-key'
param encryptionKeyPreviousUri = 'https://tsdswakv.vault.azure.net/secrets/encryption-key' // Note: Update with specific version when using previous revision

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
    value: 'dev-swa'
  }
  {
    name: 'COSMOS_CONTAINER_NAME'
    value: 'secrets'
  }
  {
    name: 'COSMOS_ENDPOINT'
    value: 'https://ts-d-swa-cosmos.documents.azure.com:443/'
  }
]

// Container App ingress configuration
param useExternalIngress = true
