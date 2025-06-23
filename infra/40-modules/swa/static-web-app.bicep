// Deploys a “blank” Static Web App
@description('Static Web App name')
param swaName string

@description('Location (Static Web Apps aren’t in every region; West Europe works for EU)')
@allowed([
  'westeurope'
  'centralus'
  'eastus2'
])
param location string

@description('Repository URL for the static web app')
param repositoryUrl string = ''

@description('Branch name for deployment')
param branch string = 'main'

@description('Backend Container App ID for API routing (optional)')
param backendResourceId string = ''

@description('SKU for the static web app.')
param sku string = 'Standard'

@description('Common tags')
param tags object

resource swa 'Microsoft.Web/staticSites@2024-04-01' = {
  name: swaName
  location: location   // must be one of the allowed regions
  sku: {
    name: sku
    tier: sku  
  }
  tags: tags
  properties: {
    allowConfigFileUpdates: true
    provider: repositoryUrl != '' ? 'GitHub' : 'None'
    repositoryUrl: repositoryUrl != '' ? repositoryUrl : null
    branch: repositoryUrl != '' ? branch : null
    buildProperties: repositoryUrl != '' ? {
      appLocation: '/'
      apiLocation: ''
      outputLocation: 'build'
    } : null    
    stagingEnvironmentPolicy: 'Enabled'
    enterpriseGradeCdnStatus: 'Disabled'
  }
}

// Link SWA to Container App for API routing WITHOUT authentication
resource staticWebAppBackend 'Microsoft.Web/staticSites/linkedBackends@2022-09-01' = if (!empty(backendResourceId)) {
  name: 'containerapp'
  parent: swa
  properties: {
    backendResourceId: backendResourceId
    region: location
  }
}

// Outputs
output staticWebAppId string = swa.id
output staticWebAppHostname string = swa.properties.defaultHostname
output staticWebAppUrl string = 'https://${swa.properties.defaultHostname}'
output staticWebAppName string = swa.name
output backendLinkResourceId string = staticWebAppBackend.id
