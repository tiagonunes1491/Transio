// infra/40-modules/swa/static-web-app.bicep
// Deploys Azure Static Web App - Unopinionated module

// ========== PARAMETERS ==========

@description('Static Web App name')
param swaName string

@description('Location for the Static Web App')
param location string

@description('Repository URL for the static web app')
param repositoryUrl string = ''

@description('Branch name for deployment')
param branch string = 'main'

@description('Backend resource ID for API routing (optional)')
param backendResourceId string = ''

@description('SKU for the static web app')
param sku string = 'Free'

@description('Tags for the Static Web App')
param tags object = {}

@description('Allow configuration file updates')
param allowConfigFileUpdates bool = true

@description('Repository provider (GitHub, GitLab, Bitbucket, etc.)')
param provider string = 'None'

@description('Build properties for the static web app')
param buildProperties object = {}

@description('Staging environment policy (Enabled, Disabled)')
param stagingEnvironmentPolicy string = 'Enabled'

@description('Enterprise grade CDN status (Enabled, Disabled)')
param enterpriseGradeCdnStatus string = 'Disabled'

@description('Linked backend name')
param linkedBackendName string = 'backend'

@description('Environment variables for the static web app')
param environmentVariables object = {}

@description('Custom domains for the static web app')
param customDomains array = []

// ========== STATIC WEB APP ==========

resource swa 'Microsoft.Web/staticSites@2024-04-01' = {
  name: swaName
  location: location
  sku: {
    name: sku
    tier: sku  }
  tags: tags
  properties: {
    allowConfigFileUpdates: allowConfigFileUpdates
    provider: provider
    repositoryUrl: repositoryUrl != '' ? repositoryUrl : null
    branch: repositoryUrl != '' ? branch : null
    buildProperties: !empty(buildProperties) ? buildProperties : null
    stagingEnvironmentPolicy: stagingEnvironmentPolicy
    enterpriseGradeCdnStatus: enterpriseGradeCdnStatus
  }
}

// Environment variables configuration
resource swaConfig 'Microsoft.Web/staticSites/config@2024-04-01' = if (!empty(environmentVariables)) {
  name: 'appsettings'
  parent: swa
  properties: environmentVariables
}

// Custom domains
resource swaDomains 'Microsoft.Web/staticSites/customDomains@2024-04-01' = [for domain in customDomains: {
  name: domain.name
  parent: swa
  properties: {
    validationMethod: domain.validationMethod
  }
}]

// Link to backend resource
resource staticWebAppBackend 'Microsoft.Web/staticSites/linkedBackends@2022-09-01' = if (!empty(backendResourceId)) {
  name: linkedBackendName
  parent: swa
  properties: {
    backendResourceId: backendResourceId
    region: location
  }
}

// ========== OUTPUTS ==========
output staticWebAppId string = swa.id
output staticWebAppHostname string = swa.properties.defaultHostname
output staticWebAppUrl string = 'https://${swa.properties.defaultHostname}'
output staticWebAppName string = swa.name
output backendLinkResourceId string = !empty(backendResourceId) ? staticWebAppBackend.id : ''
