// This file is used to deploy the main.bicep file in the dev environment
using 'swa-aca-platform.bicep'

// Parameters for deployment scope
param resourceLocation  = 'spaincentral'
param rgName = 'rg-ssharer-paas-spoke-dev'
param tags  = {
  environment: 'dev'
  project: 'secure-secret-sharer'
  owner: 'Tiago'
  flavor: 'SWA-ACA'
}

// Parameters for the vnet
param vnetName = 'vnet-securesharer-dev'

// Parameters for the AKV
param akvName = 'kv-securesharer-swa-dev'
param akvSku = 'standard'
param akvRbac = true
param akvPurgeProtection = false
param akvSecrets = {
  'database-user': 'secret_sharer_app_user'
  'database-password': 'nCNH6O5bx0czbBXYRSdo5sbwo8nILv5J'
  'master-encryption-key': 'rBrSuPVrALiP_nsyWX5hnr-zvdL2Jt6gQ-wNDpK9xkw='
  'postgres-admin-user': 'pgadminuser'
  'postgres-admin-password': 'nQVvMqOF4CINSvYBUoUH9ZnCZnkFaluH'
}


// Parameters for the ACR
param acrName = 'acrsecuresecretsharerdev'
param acrSku = 'Premium'
param acrEnableAdminUser = false

// Parameters for workspace
param workspaceName = 'ws-sec-sharer-dev'

// Parameters for the Azure Container Apps
param acaEnvName = 'cae-sharer-aca-dev'
param acaUamiName = [
  'aca-sharer-identity'
]

// Parameters for the Postgres
param dbServerName = 'pgs-sharer-aca-dev'

// Parameters for storage account
param storageAccountName = 'sadeploysharerdev'

