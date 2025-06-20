// Private Endpoint configuration
// Creates private endpoints for secure access to Azure services
@description('Private Endpoint name')
param privateEndpointName string
@description('Private Endpoint location')
param privateEndpointLocation string
@description('Private Endpoint subnet ID')
param privateEndpointSubnetId string
@description('Private Endpoint group ID')
param privateEndpointGroupId string
@description('Private Endpoint service ID')
param privateEndpointServiceId string
@description('Private Endpoint tags')
param privateEndpointTags object = {}
@description('IDs of private DNS zones to link (optional)')
param privateDnsZoneIds array = []

var dnsConfigs = [for zoneId in privateDnsZoneIds: {
  name: uniqueString(zoneId)
  properties: {
    privateDnsZoneId: zoneId
  }
}]

// automatically create the zone-group when at least one zone is supplied
resource dnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = if (length(privateDnsZoneIds) > 0) {
  name: 'default'
  parent: privateEndpoint
  properties: {
    privateDnsZoneConfigs: dnsConfigs
  }
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: privateEndpointName
  location: privateEndpointLocation
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${privateEndpointName}-connection'
        properties: {
          privateLinkServiceId: privateEndpointServiceId
          groupIds: [
            privateEndpointGroupId
          ]
          requestMessage: 'Auto-approved connection for ${privateEndpointName}'
        }
      }
    ]
  }
  tags: privateEndpointTags
}

// Outputs
output privateEndpointId string = privateEndpoint.id
output privateEndpointName string = privateEndpoint.name
