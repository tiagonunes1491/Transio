using 'main.bicep'

param environmentName = 'prod'
param projectCode = 'ts'
param serviceCode = 'swa'  // Platform-specific: use 'swa' or 'aks'
param resourceLocation = 'spaincentral'
param kvSku = 'premium'
param kvRbac = true
param kvPurgeProtection = true
param kvEnablePublicNetworkAccess = true
param kvNetworkAclsDefaultAction = 'Deny'
param costCenter = '1000'
param createdBy = 'bicep-deployment'
param owner = ''
param ownerEmail = ''
