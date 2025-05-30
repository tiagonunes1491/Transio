@description('The Azure Container Apps Environment name.')
param acaEnvironmentName string
@description('The location for the Azure Container Apps Environment.')
param acaEnvironmentLocation string = resourceGroup().location
@description('The tags for the Azure Container Apps Environment.')
param acaEnvironmentTags object = {}
@description('The workspace ID for the Azure Container Apps Environment.')
param workspaceId string
@description('The VNET subnet ID the Azure Container Apps Environment.')
param acaEnvironmentSubnetId string

resource acaEnvironment 'Microsoft.App/managedEnvironments@2024-05-01' = {
  name: acaEnvironmentName
  location: acaEnvironmentLocation
  tags: acaEnvironmentTags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: reference(workspaceId, '2022-10-01').properties.customerId
        sharedKey: listKeys(workspaceId, '2022-10-01').primarySharedKey
      }
    }
    vnetConfiguration: {
      infrastructureSubnetId: acaEnvironmentSubnetId
      internal: false
    }
  }
}

output acaEnvironmentId string = acaEnvironment.id
output acaDefaultDomain string = acaEnvironment.properties.defaultDomain
