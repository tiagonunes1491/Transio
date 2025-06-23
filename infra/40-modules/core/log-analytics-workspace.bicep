// Log Analytics Workspace configuration
// Creates Log Analytics workspace for monitoring and logging
@description('Name of the workspace')
param workspaceName string
@description('Location for the workspace')
param location string = resourceGroup().location
@description('Tags for the workspace')
param tags object = {}

resource workspace 'Microsoft.OperationalInsights/workspaces@2025-02-01' = {
  name: workspaceName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30 // Default retention period}
  }
}

output workspaceId string = workspace.id
output workspaceName string = workspace.name
output workspaceCustomerId string = workspace.properties.customerId
@secure()
output workspaceSharedKey string = listKeys(workspace.id, '2022-10-01').primarySharedKey
