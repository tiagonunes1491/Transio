using 'main.bicep'

param environmentName = 'dev'
param projectCode = 'ss'
param serviceCode = 'aks'  // Platform-specific for AKS
param resourceLocation = 'spaincentral'
param kvSku = 'standard'
param kvRbac = true
param kvPurgeProtection = true
param kvEnablePublicNetworkAccess = true
param kvNetworkAclsDefaultAction = 'Allow'
param costCenter = '1000'
param createdBy = 'bicep-deployment'
param owner = ''
param ownerEmail = ''
