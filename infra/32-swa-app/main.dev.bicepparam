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
param keyVaultSecrets = [
  {
    name: 'cosmos-connection-string'
    keyVaultUri: 'https://ssdswakv.vault.azure.net/secrets/cosmos-connection-string'
  }
  {
    name: 'encryption-key'
    keyVaultUri: 'https://ssdswakv.vault.azure.net/secrets/encryption-key'
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
    name: 'COSMOS_DATABASE_NAME'
    value: 'swa-dev'
  }
  {
    name: 'SECRET_EXPIRY_HOURS'
    value: '24'
  }
]

// Secret environment variables (referencing Key Vault secrets)
param secretEnvironmentVariables = [
  {
    name: 'COSMOS_CONNECTION_STRING'
    secretRef: 'cosmos-connection-string'
  }
  {
    name: 'ENCRYPTION_KEY'
    secretRef: 'encryption-key'
  }
]
