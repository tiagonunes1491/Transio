// Azure Container Apps Environment (CAE) configuration
// Creates a managed environment for Container Apps with configurable networking and monitoring
@description('Name of the Container Apps Environment')
param caeName string

@description('Location for the Container Apps Environment')
param location string = resourceGroup().location

@description('Tags for the Container Apps Environment')
param tags object = {}

@description('Log Analytics workspace resource ID for monitoring')
param logAnalyticsWorkspaceId string = ''

@description('Enable Log Analytics integration')
param enableLogAnalytics bool = true

@description('Virtual network configuration')
param vnetConfiguration object = {
  internal: false
  infrastructureSubnetId: ''
}

@description('Enable virtual network integration')
param enableVnetIntegration bool = false

@description('Enable zone redundancy for high availability')
param enableZoneRedundancy bool = false

@description('Workload profiles for the environment')
param workloadProfiles array = []

@description('Enable Dapr configuration')
param enableDapr bool = false

@description('Dapr configuration settings')
param daprConfiguration object = {}

@description('Mutual TLS configuration')
param mtlsConfiguration object = {
  enabled: false
}

@description('Custom domain configuration')
@secure()
param customDomainConfiguration object = {}

@description('Enable custom domain')
param enableCustomDomain bool = false

@description('Enable Keda scaling')
param enableKedaConfiguration bool = false

@description('Keda configuration settings')
param kedaConfiguration object = {}

@description('Enable peer authentication for mTLS')
param enablePeerAuthentication bool = false

@description('Infrastructure resource group for CAE')
param infrastructureResourceGroup string = ''


resource caeEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: caeName
  location: location
  tags: tags
  properties: {
    // Log Analytics configuration - only if enabled and workspace provided
    appLogsConfiguration: enableLogAnalytics && !empty(logAnalyticsWorkspaceId) ? {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: reference(logAnalyticsWorkspaceId, '2022-10-01').customerId
        sharedKey: listKeys(logAnalyticsWorkspaceId, '2022-10-01').primarySharedKey
      }
    } : null
    
    // Virtual network configuration - only if enabled
    vnetConfiguration: enableVnetIntegration ? {
      internal: vnetConfiguration.internal
      infrastructureSubnetId: vnetConfiguration.infrastructureSubnetId
    } : null
    
    // Zone redundancy configuration
    zoneRedundant: enableZoneRedundancy
    
    // Workload profiles - for dedicated compute
    workloadProfiles: workloadProfiles
      // Dapr configuration - only if enabled
    daprConfiguration: enableDapr ? daprConfiguration : null
    
    // Mutual TLS configuration
    peerAuthentication: enablePeerAuthentication ? {
      mtls: {
        enabled: mtlsConfiguration.enabled
      }
    } : null
    
    // Custom domain configuration - only if enabled
    customDomainConfiguration: enableCustomDomain ? customDomainConfiguration : null
    
    // Keda configuration - only if enabled
    kedaConfiguration: enableKedaConfiguration ? kedaConfiguration : null
    
    // Infrastructure resource group - optional
    infrastructureResourceGroup: !empty(infrastructureResourceGroup) ? infrastructureResourceGroup : null
  }
}

output caeId string = caeEnvironment.id
output caeDefaultDomain string = caeEnvironment.properties.defaultDomain
output caeName string = caeEnvironment.name
output caeLocation string = caeEnvironment.location
output caeStaticIp string = enableVnetIntegration ? caeEnvironment.properties.staticIp : ''
output caeEventStreamEndpoint string = caeEnvironment.properties.eventStreamEndpoint
