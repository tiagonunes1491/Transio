/*
 * =============================================================================
 * Static Web App Module
 * =============================================================================
 * 
 * This Bicep module creates and configures Azure Static Web Apps for hosting
 * frontend applications. It provides a modern hosting platform with global CDN, 
 * automatic scaling, and integrated CI/CD capabilities optimized for modern web 
 * frameworks.
 * 
 * ARCHITECTURE OVERVIEW:
 * ┌─────────────────────────────────────────────────────────────────────────┐
 * │                Static Web App Architecture                              │
 * ├─────────────────────────────────────────────────────────────────────────┤
 * │  Global Edge Network                                                    │
 * │  ┌─────────────────────────────────────────────────────────────────────┐│
 * │  │ Content Delivery Network (CDN)                                      ││
 * │  │ ┌─────────────────────┐  ┌─────────────────────────────────────┐   ││
 * │  │ │ Edge Locations      │  │ SSL/TLS Termination                 │   ││
 * │  │ │ • Global caching    │  │ • Automatic certificates            │   ││
 * │  │ │ • Edge routing      │  │ • Custom domain support             │   ││
 * │  │ │ • Performance       │  │ • HTTPS enforcement                 │   ││
 * │  │ └─────────────────────┘  └─────────────────────────────────────┘   ││
 * │  │                                                                     ││
 * │  │ Application Platform                                                ││
 * │  │ ┌─────────────────────┐  ┌─────────────────────────────────────┐   ││
 * │  │ │ Static Content      │  │ API Integration                     │   ││
 * │  │ │ • React frontend    │  │ • Backend routing                   │   ││
 * │  │ │ • SPA routing       │  │ • CORS configuration                │   ││
 * │  │ │ • Asset optimization│  │ • Authentication                    │   ││
 * │  │ └─────────────────────┘  └─────────────────────────────────────┘   ││
 * │  │                                                                     ││
 * │  │ CI/CD Integration                                                   ││
 * │  │ ┌─────────────────────┐  ┌─────────────────────────────────────┐   ││
 * │  │ │ GitHub Integration  │  │ Automated Deployment                │   ││
 * │  │ │ • Repository linking│  │ • Build automation                  │   ││
 * │  │ │ • Branch triggers   │  │ • Preview environments              │   ││
 * │  │ │ • Configuration     │  │ • Production deployment             │   ││
 * │  │ └─────────────────────┘  └─────────────────────────────────────┘   ││
 * │  └─────────────────────────────────────────────────────────────────────┘│
 * └─────────────────────────────────────────────────────────────────────────┘
 * 
 * KEY FEATURES:
 * • Global CDN: Automatic global content distribution with edge caching
 * • GitHub Integration: Native GitHub repository integration with automated deployments
 * • Custom Domains: Support for custom domains with automatic SSL certificate management
 * • API Integration: Seamless backend API routing and integration capabilities
 * • Authentication: Built-in authentication providers and custom authentication support
 * • Preview Environments: Automatic preview deployments for pull requests
 * • Performance Optimization: Automatic asset optimization and compression
 * • Scalable Infrastructure: Automatic scaling based on traffic demands
 * 
 * SECURITY CONSIDERATIONS:
 * • Automatic SSL/TLS certificate provisioning and management
 * • HTTPS enforcement for all traffic with HSTS headers
 * • Authentication and authorization integration with Azure AD
 * • CORS configuration for secure cross-origin requests
 * • Content Security Policy support for XSS protection
 * • Built-in DDoS protection through Azure infrastructure
 * • Secure header injection for enhanced security posture
 * 
 * DEPLOYMENT SCOPE:
 * This module operates at resource group scope to create Static Web App
 * resources that can host modern web applications with global distribution
 * and integrated development workflows.
 */

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
