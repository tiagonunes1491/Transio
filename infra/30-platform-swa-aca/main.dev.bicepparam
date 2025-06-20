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

// Shared infrastructure references - these should match existing resources
param acrName = 'acrsecsharer'
param acrLoginServer = 'acrsecsharer.azurecr.io'
param acrId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ssharer-artifacts-hub/providers/Microsoft.ContainerRegistry/registries/acrsecsharer'
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

param acaEnvName = 'cae-sharer-aca-dev'

// Container App stub configuration
param stubContainerAppName = 'app-ss-aca-dev'
param stubContainerImage = 'acrsecsharer.azurecr.io/hello-world:latest'

// Static Web App configuration  
param swaName = 'swa-secure-sharer-dev'
