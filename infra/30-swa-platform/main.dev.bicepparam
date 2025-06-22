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

// Key Vault configuration
param akvSku = 'standard'
param akvRbac = true
param akvPurgeProtection = false
param akvSecrets = {
  'cosmos-endpoint': 'https://ss-s-plat-cosmos.documents.azure.com:443/'
  'encryption-key': '=fF3jdnJGZiQWSTrGD9kM2I5_7oP8qRsT6uVwXyZaBcE='
  'cosmos-database-name': 'swa-dev'
  'cosmos-container-name': 'secrets'
}

