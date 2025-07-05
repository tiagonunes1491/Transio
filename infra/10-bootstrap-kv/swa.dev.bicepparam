using 'main.bicep'

param environmentName = 'dev'
param projectCode = 'ss'
param serviceCode = 'swa'  // Platform-specific: use 'swa' or 'aks'
param resourceLocation = 'spaincentral'
param kvSku = 'standard'
param kvRbac = true
param kvPurgeProtection = false
param kvEnablePublicNetworkAccess = true
param kvNetworkAclsDefaultAction = 'Allow'
param costCenter = '1000'
param createdBy = 'bicep-deployment'
param owner = ''
param ownerEmail = ''
