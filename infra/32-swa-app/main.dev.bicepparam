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
param acaEnvironmentResourceGroupName = 'ss-d-swa-rg'
param acaEnvironmentName = 'ss-d-swa-cae'
param uamiResourceGroupName = 'ss-i-mgmt-rg'
param uamiName = 'ss-d-swa-id-ca-backend'

// Application configuration
param containerImage = 'sssplatacr.azurecr.io/secure-secret-sharer:dev'

// Key Vault secrets configuration
param keyVaultSecrets = [  {
    name: 'cosmos-endpoint'
    keyVaultUrl: 'https://ssdswakv.vault.azure.net/secrets/cosmos-endpoint'
  }
  {
    name: 'encryption-key'
    keyVaultUrl: 'https://ssdswakv.vault.azure.net/secrets/encryption-key'
  }
  {
    name: 'cosmos-database-name'
    keyVaultUrl: 'https://ssdswakv.vault.azure.net/secrets/cosmos-database-name'
  }
  {
    name: 'cosmos-container-name'
    keyVaultUrl: 'https://ssdswakv.vault.azure.net/secrets/cosmos-container-name'
  }
]

// Environment variables
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
]

// Secret environment variables (referencing Key Vault secrets)
param secretEnvironmentVariables = [
  {
    name: 'COSMOS_ENDPOINT'
    secretRef: 'cosmos-endpoint'
  }
  {
    name: 'MASTER_ENCRYPTION_KEY'
    secretRef: 'encryption-key'
  }
  {
    name: 'COSMOS_DATABASE_NAME'
    secretRef: 'cosmos-database-name'
  }
  {
    name: 'COSMOS_CONTAINER_NAME'
    secretRef: 'cosmos-container-name'
  }
]
