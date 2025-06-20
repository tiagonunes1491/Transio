// Private DNS Zone configuration
// Creates private DNS zones and VNet links for private endpoints
@description('Private DNS Zone name')
param privateDnsZoneName string
@description('Virtual Network ID for the Private DNS Zone link')
param vnetId string
@description('Private DNS Zone tags')
param privateDnsZoneTags object = {}

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: privateDnsZoneName
  location: 'global'
  tags: privateDnsZoneTags
  properties: {}
}

resource privateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  name: 'link-to-${uniqueString(vnetId)}'
  parent: privateDnsZone
  location: 'global'
  properties: {
    virtualNetwork: {
      id: vnetId
    }
    registrationEnabled: false
  }
}

output privateDnsZoneId string = privateDnsZone.id
output privateDnsZoneName string = privateDnsZone.name
