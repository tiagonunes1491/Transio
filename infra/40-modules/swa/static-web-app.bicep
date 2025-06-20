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

@description('User-assigned identity (optional but handy for RBAC later)')
param uamiId string

@description('Common tags')
param tags object

resource swa 'Microsoft.Web/staticSites@2024-11-01' = {
  name: swaName
  location: location   // must be one of the allowed regions
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${uamiId}': {}
    }
  }
  sku: {
    name: 'Free'
    tier: 'Free'
  }
  tags: tags
  properties: {
    allowConfigFileUpdates: true
  }
}

output staticWebAppId string = swa.id
