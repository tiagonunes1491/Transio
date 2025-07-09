using 'main.bicep'

param environmentName = 'prod'
param projectCode = 'ts'
param serviceCode = 'aks'  // Platform-specific for AKS
param resourceLocation = 'spaincentral'
param kvSku = 'premium'
param kvRbac = true
param kvPurgeProtection = true
param kvEnablePublicNetworkAccess = false
param kvNetworkAclsDefaultAction = 'Deny'
param costCenter = '1000'
param createdBy = 'bicep-deployment'
param owner = ''
param ownerEmail = ''
