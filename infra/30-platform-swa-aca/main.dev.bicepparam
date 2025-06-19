// main.bicepparam

using 'main.bicep'

param tenantId = '00000000-0000-0000-0000-000000000000'
param resourceLocation = 'westeurope'
param rgName = 'rg-secure-sharer-swa-aca-dev'

param tags = {
  environment: 'dev'
  project: 'secure-secret-sharer'
  owner: 'Tiago'
  flavor: 'SWA-ACA'
}

param sharedResourceGroupName = 'rg-ssharer-artifacts-hub'
param cosmosDbAccountName = 'cosmos-sharer-hub'
param cosmosDbEndpoint = 'https://cosmos-sharer-hub.documents.azure.com:443/'
param cosmosDatabaseName = 'SecureSharer'
param cosmosContainerName = 'secrets'

param akvName = 'kv-sec-secret-sharer'
param akvSku = 'standard'
param akvRbac = true
param akvPurgeProtection = true
param akvSecrets = {
  databaseUser: 'db-user-secret-name'
  databasePassword: 'db-password-secret-name'
  masterEncryptionKey: 'master-key-secret-name'
}

param vnetName = 'vnet-secureSecretSharer'

param acrName = 'acrsecsharer'
param acrSku = 'Standard'
param acrEnableAdminUser = false

param workspaceName = 'ws-sec-sharer'

param acaEnvName = 'cae-sharer-aca-dev'
param acaUamiName = [
  'aca-sharer-identity'
]

param storageAccountName = 'sadeploysharerdev'

// ACA App Stub Parameters
param acaAppName = 'secure-secret-sharer-aca-dev'
param acaCpuLimit = '0.25'
param acaMemoryLimit = '0.5Gi'
param acaImage = 'acrsecsharer.azurecr.io/app-placeholder:latest'

// SWA App Stub Parameters
param staticWebAppName = 'swa-secure-sharer-dev'
param staticWebAppRepo = 'https://github.com/your-org/your-repo'
param staticWebAppBranch = 'main'
param staticWebAppSku = 'Standard'
