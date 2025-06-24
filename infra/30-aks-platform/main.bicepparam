// Bicep parameters file for AKS platform deployment
// This file configures the AKS platform infrastructure including:
// - AKS cluster and node pools
// - Application Gateway and networking
// - Key Vault and Container Registry integration
// - Federated identity credentials for workloads

using 'main.bicep'

// Environment configuration
param resourceLocation = 'spaincentral'
param rgName = 'rg-ssharer-k8s-spoke-dev'
param tags = {
  environment: 'dev'
  project: 'secure-secret-sharer'
  owner: 'Tiago'
}

// Virtual network configuration
param vnetName = 'vnet-securesharer-dev'

// Azure Container Registry configuration
param acrName = 'acrsecuresecretsharerdev'
param acrSku = 'Standard'
param acrEnableAdminUser = false

// Azure Key Vault configuration
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

// AKS cluster configuration
param aksName = 'aks-securesharer-dev'
param kubernetesVersion = '1.31.7'
param systemNodePoolVmSize = 'Standard_D8ds_v5'
param userNodePoolVmSize = 'Standard_D8ds_v5'
param aksAdminGroupObjectIds = [
  '881fa64b-3783-4880-8920-0d297899074c'
]

// Federated identity configuration
// This order is important, as the array will be used to pass configurations across the module.
// First object is for backend and second for database.
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

// Network security configuration
param appGwNsgName = 'nsg-securesharer-dev'

// Application Gateway configuration
param appGwName = 'appgw-securesharer-dev'
param appGwSku = 'WAF_v2'
param appGwPublicIpName = 'appgw-public-ip-dev'
