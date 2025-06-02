@description('The name of the static web app.')
param staticWebAppName string
@description('The location of the static web app.')
param location string = resourceGroup().location
@description('SKU for the static web app.')
param sku string = 'Standard'
@description('custom domain for the static web app')
param customDomain string = ''
@description('Tag for the static web app')
param tag object = {}
@description('Repository URL for the static web app')
param repositoryUrl string = ''
@description('Branch name for deployment')
param branch string = 'main'
@description('Backend API FQDN for the static web app')
param backendApiFqdn string = ''
@description('Additional app settings')
param appSettings object = {}

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
    enterpriseGradeCdnStatus: sku == 'Standard' ? 'Enabled' : 'Disabled'
  }
}

// App settings configuration - only deploy if we have settings to configure
resource swaAppSettings 'Microsoft.Web/staticSites/config@2022-09-01' = if (backendApiFqdn != '' || !empty(appSettings)) {
  parent: staticWebApp
  name: 'appsettings'
  properties: union(
    backendApiFqdn != '' ? {
      API_BASE_URL: backendApiFqdn
    } : {},
    appSettings
  )
}

// Custom domain configuration with validation
resource customDomainResource 'Microsoft.Web/staticSites/customDomains@2023-12-01' = if (customDomain != '') {
  parent: staticWebApp
  name: customDomain
  properties: {
    validationMethod: 'cname-delegation'
  }
}

// Outputs
output staticWebAppUrl string = 'https://${staticWebApp.properties.defaultHostname}'
output staticWebAppId string = staticWebApp.id
output staticWebAppName string = staticWebApp.name
output customDomainId string = customDomain != '' ? customDomainResource.id : ''
output defaultHostname string = staticWebApp.properties.defaultHostname
