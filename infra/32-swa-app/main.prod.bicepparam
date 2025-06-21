using './main.bicep'

// Basic configuration
param resourceLocation = 'spaincentral'
param projectCode = 'ss'
param serviceCode = 'swa'
param environmentName = 'prod'

// Tagging configuration
param costCenter = '1000'
param createdBy = 'bicep-deployment-prod'
param owner = 'tiago-nunes'
param ownerEmail = 'tiago.nunes@microsoft.com'

// Existing infrastructure references
param acaEnvironmentResourceGroupName = 'ss-p-swa-rg'
param acaEnvironmentName = 'ss-p-swa-cae'
param acrResourceGroupName = 'ss-s-plat-rg'
param acrName = 'sssplatacr'
param uamiResourceGroupName = 'ss-i-mgmt-rg'
param uamiName = 'ss-p-swa-id'

// Application configuration
param containerImage = 'sssplatacr.azurecr.io/secure-secret-sharer:latest'

// Key Vault secrets configuration
param keyVaultSecrets = [
  {
    name: 'cosmos-connection-string'
    keyVaultUri: 'https://sspswakv.vault.azure.net/secrets/cosmos-connection-string'
  }
  {
    name: 'encryption-key'
    keyVaultUri: 'https://sspswakv.vault.azure.net/secrets/encryption-key'
  }
  {
    name: 'app-insights-connection-string'
    keyVaultUri: 'https://sspswakv.vault.azure.net/secrets/app-insights-connection-string'
  }
]

// Environment variables
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
    name: 'COSMOS_DATABASE_NAME'
    value: 'secrets-db'
  }
  {
    name: 'SECRET_EXPIRY_HOURS'
    value: '48'
  }
]
