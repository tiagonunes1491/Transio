using 'main.bicep'

param environmentName = 'dev'
param projectCode = 'ts'
param serviceCode = 'swa'  // Platform-specific: use 'swa' or 'aks'
param resourceLocation = 'spaincentral'
param kvSku = 'standard'
param kvRbac = true
param kvPurgeProtection = true
param costCenter = '1000'
param createdBy = 'bicep-deployment'
param owner = ''
param ownerEmail = ''
