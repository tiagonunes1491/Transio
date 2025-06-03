@description('The name of the static web app.')
param staticWebAppName string
@description('The location of the static web app.')
param location string = resourceGroup().location
@description('SKU for the static web app.')
param sku string = 'Standard'
@description('Tag for the static web app')
param tag object = {}
@description('Repository URL for the static web app')
param repositoryUrl string = ''
@description('Branch name for deployment')
param branch string = 'main'
@description('Backend API resource ID to link')
param backendApiResourceId string = ''

resource staticWebApp 'Microsoft.Web/staticSites@2024-04-01' = {
  name: staticWebAppName
  location: location
  tags: tag
  sku: {
    name: sku
    tier: sku
  }
  properties: {
    // Set provider to None for manual deployment or GitHub for automatic
    provider: repositoryUrl != '' ? 'GitHub' : 'None'
    repositoryUrl: repositoryUrl != '' ? repositoryUrl : null
    branch: repositoryUrl != '' ? branch : null
    buildProperties: repositoryUrl != '' ? {
      appLocation: '/'
      apiLocation: ''
      outputLocation: 'build'
    } : null
    // Enable staging environments for better development workflow
    stagingEnvironmentPolicy: 'Enabled'
    // Allow configuration overrides
    allowConfigFileUpdates: true
    // Enterprise features
    enterpriseGradeCdnStatus: 'Disabled'
  }
}

// Link to backend if provided
resource backendLink 'Microsoft.Web/staticSites/linkedBackends@2024-04-01' = if (backendApiResourceId != '') {
  parent: staticWebApp
  name: 'api'
  properties: {
    backendResourceId: backendApiResourceId
  }
}

// Outputs
output staticWebAppUrl string = 'https://${staticWebApp.properties.defaultHostname}'
output staticWebAppId string = staticWebApp.id
output staticWebAppName string = staticWebApp.name
output defaultHostname string = staticWebApp.properties.defaultHostname
