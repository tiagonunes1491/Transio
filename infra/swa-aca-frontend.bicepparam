using 'swa-aca-frontend.bicep'

param staticWebAppName = 'swa-secure-sharer-frontend-dev'
param location = 'westeurope'
param sku = 'Standard'
param tag = {
  environment: 'dev'
  project: 'secure-secret-sharer'
  owner: 'Tiago'
  version: 'v1'
}
param repositoryUrl = ''
param branch = ''
