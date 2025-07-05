using 'main.bicep'

param environmentName = 'dev'
param projectCode = 'ss'
param serviceCode = 'swa'  // Platform-specific: use 'swa' or 'aks'
param resourceLocation = 'spaincentral'
param kvSku = 'standard'
param kvRbac = true
param kvPurgeProtection = true
param costCenter = '1000'
param createdBy = 'bicep-deployment'
param owner = 'tiago-nunes'
param ownerEmail = 'tiago.nunes@example.com'
