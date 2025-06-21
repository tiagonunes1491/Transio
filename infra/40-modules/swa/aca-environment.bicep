// Azure Container Apps Environment configuration
// Creates a managed environment for Container Apps with networking and monitoring
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


resource acaEnvironment 'Microsoft.App/managedEnvironments@2025-01-01' = {
  name: acaEnvironmentName
  location: acaEnvironmentLocation
  tags: acaEnvironmentTags
  identity: {
    type: 'SystemAssigned'  // Enable system-assigned managed identity for CAE
  }
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: reference(workspaceId, '2022-10-01').customerId
         #disable-next-line use-secure-value-for-secure-inputs
        sharedKey:  listKeys(workspaceId, '2022-10-01').primarySharedKey  // secureString
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
output acaEnvironmentPrincipalId string = acaEnvironment.identity.principalId  // System identity principal ID for RBAC
