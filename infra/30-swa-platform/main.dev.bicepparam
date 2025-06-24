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

// Shared infrastructure references - these should match existing resources
param acrName = 'sssplatacr'
param sharedResourceGroupName = 'ss-s-plat-rg'
param cosmosDbAccountName = 'ss-s-plat-cosmos'

// Key Vault configuration
param akvSku = 'standard'
param akvRbac = true
param akvPurgeProtection = false
param akvSecrets = {
  'cosmos-endpoint': {
    value: 'https://ss-s-plat-cosmos.documents.azure.com:443/'
    contentType: 'uri'
    expires: 1782585600
  }
  'encryption-key': {
    value: '=fF3jdnJGZiQWSTrGD9kM2I5_7oP8qRsT6uVwXyZaBcE='
    contentType: 'base64'
    expires: 1782585600
  }
  'cosmos-database-name': {
    value: 'swa-dev'
    contentType: 'string'
    expires: 1782585600
  }
  'cosmos-container-name': {
    value: 'secrets'
    contentType: 'string'
    expires: 1782585600
  }
}

