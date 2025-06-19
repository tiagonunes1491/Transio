// This file is used to deploy the main.bicep file in the dev environment
using 'k8s-main.bicep'

// Parameters for deployment scope
param resourceLocation  = 'spaincentral'
param rgName = 'rg-ssharer-k8s-spoke-dev'
param tags  = {
  environment: 'dev'
  project: 'secure-secret-sharer'
  owner: 'Tiago'
}

// Parameters for the vnet
param vnetName = 'vnet-securesharer-dev'

// Parameters for the ACR
param acrName = 'acrsecuresecretsharerdev'
param acrSku = 'Standard'
param acrEnableAdminUser = false


// Parameters for the AKV
param akvName = 'kv-securesharer-dev'
param akvSku = 'standard'
param akvRbac = true
param akvPurgeProtection = false
param akvSecrets = {
  'app-db-user': 'secret_sharer_app_user'
  'app-db-password': 'nCNH6O5bx0czbBXYRSdo5sbwo8nILv5J'
  'app-master-encryption-key': 'rBrSuPVrALiP_nsyWX5hnr-zvdL2Jt6gQ-wNDpK9xkw='
  'postgres-password': 'nQVvMqOF4CINSvYBUoUH9ZnCZnkFaluH'
}

// Parameters for the AKS
param aksName = 'aks-securesharer-dev'
param kubernetesVersion = '1.31.7'
param systemNodePoolVmSize = 'Standard_D8ds_v5'
param userNodePoolVmSize = 'Standard_D8ds_v5'
param aksAdminGroupObjectIds = [
  '881fa64b-3783-4880-8920-0d297899074c'
]

//Parameters for the FIC
//This order is important, as the array will be used to pass configurations across the module.
//First object is for backend and second for database.
param federationConfigs = [
  {
    uamiTargetName: 'uami-securesharer-backend-dev' 
    k8sServiceAccountName: 'secret-sharer-backend-sa'
    k8sNamespace: 'default' 
  }
  {
    uamiTargetName: 'uami-securesharer-db-dev' 
    k8sServiceAccountName: 'secret-sharer-db-init-sa'
    k8sNamespace: 'default' 
  }
]

// Parameters for secure network
param appGwNsgName = 'nsg-securesharer-dev'

//Parameters for the app gateway
param appGwName  = 'appgw-securesharer-dev'
param appGwPublicIpName = 'appgw-public-ip-dev'
