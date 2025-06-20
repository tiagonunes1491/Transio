// main.bicepparam

using 'main.bicep'

// Basic configuration
param resourceLocation = 'westeurope'
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
param cosmosDbAccountName = 'cosmos-sharer-hub'
param cosmosDatabaseName = 'SecureSharer'
param cosmosContainerName = 'secrets'
param sharedResourceGroupName = 'ss-s-plat-rg'

// Key Vault configuration
param akvSku = 'standard'
param akvRbac = true
param akvPurgeProtection = false
param akvSecrets = {
  masterEncryptionKey: 'master-key-secret-name'
}

// Container App stub configuration
param stubContainerImage = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
