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

// Resource group references for cross-RG RBAC assignments
param sharedResourceGroupName = 'ss-s-plat-rg'        // ACR and CosmosDB location
param keyVaultResourceGroupName = 'ss-p-swa-rg'       // Key Vault location (prod-specific)

// Existing resource names
param acrName = 'sssplatacr'
param cosmosDbAccountName = 'sssplatcosmos'
param keyVaultName = 'sspswakv'                        // Production Key Vault

// Database configuration
param cosmosDatabaseName = 'secrets-db'
