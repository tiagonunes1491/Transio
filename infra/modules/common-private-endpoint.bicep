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

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: privateEndpointName
  location: privateEndpointLocation
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: privateEndpointGroupId
        properties: {
          privateLinkServiceId: privateEndpointServiceId
          groupIds: [
            privateEndpointGroupId
          ]
          requestMessage: 'Please approve the connection.'
        }
      }
    ]
  }
  tags: privateEndpointTags
}


// To get the NIC associated with the PE
resource peNic 'Microsoft.Network/networkInterfaces@2023-11-01' existing = {
  name: last(split(privateEndpoint.properties.networkInterfaces[0].id, '/'))
  scope: resourceGroup(split(privateEndpoint.properties.networkInterfaces[0].id, '/')[2], split(privateEndpoint.properties.networkInterfaces[0].id, '/')[4])
}

output privateEndpointId string = privateEndpoint.id
output privateEndpointName string = privateEndpoint.name
output ipAddress string = privateEndpoint.properties.networkInterfaces[0].properties.ipConfigurations[0].properties.privateIPAddress
