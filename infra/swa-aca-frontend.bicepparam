using 'swa-aca-frontend.bicep'

param staticWebAppName = 'swa-secure-sharer-frontend-dev'
param location = 'westeurope'
param sku = 'Standard'
param customDomain = ''
param tag = {
  environment: 'dev'
  project: 'secure-secret-sharer'
  owner: 'Tiago'
}
param repositoryUrl = ''
param branch = ''
