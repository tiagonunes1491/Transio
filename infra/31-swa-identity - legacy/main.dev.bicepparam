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

// Resource group references for cross-RG RBAC assignments
param sharedResourceGroupName = 'ss-s-plat-rg'        // ACR and CosmosDB location
param keyVaultResourceGroupName = 'ss-d-swa-rg'       // Key Vault location

// Existing resource names
param acrName = 'sssplatacr'
param cosmosDbAccountName = 'ss-s-plat-cosmos'
param keyVaultName = 'ssdswakv'

// Database configuration
param cosmosDatabaseName = 'swa-dev'
