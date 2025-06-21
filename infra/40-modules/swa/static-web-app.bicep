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

@description('Backend Container App ID for API routing (optional)')
param backendResourceId string = ''

@description('Common tags')
param tags object

resource swa 'Microsoft.Web/staticSites@2024-04-01' = {
  name: swaName
  location: location   // must be one of the allowed regions
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
  tags: tags
  properties: {
    allowConfigFileUpdates: true
    provider: 'None'
    stagingEnvironmentPolicy: 'Enabled'
    enterpriseGradeCdnStatus: 'Disabled'
  }
}

// Link SWA to Container App for API routing
resource staticWebAppBackend 'Microsoft.Web/staticSites/linkedBackends@2022-09-01' = if (!empty(backendResourceId)) {
  name: 'containerapp'
  parent: swa
  properties: {
    backendResourceId: backendResourceId
    region: location
  }
}

output staticWebAppId string = swa.id
output staticWebAppHostname string = swa.properties.defaultHostname
