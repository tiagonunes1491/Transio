// This file is used to deploy the main.bicep file in the dev environment
using 'swa-aca-app.bicep'

param appName = 'secure-secret-sharer-aca-dev'
param appLocation = 'spaincentral'
param containerImage = 'secure-secret-sharer:0.3'
param environmentId = ''
param userAssignedIdentityId = ''
param acrLoginServer = ''
param keyVaultUri = ''
param keyVaultSecrets = {
  databaseUser: 'database-user'
  databasePassword: 'database-password'
  masterEncryptionKey: 'master-encryption-key'
}
param tags  = {
  environment: 'dev'
  project: 'secure-secret-sharer'
  owner: 'Tiago'
  flavor: 'SWA-ACA'
}
param postgresqlServerFqdn = ''
param databaseName = ''
param acaCpuLimit  = '0.25'
param acaMemoryLimit  = '0.5Gi'
