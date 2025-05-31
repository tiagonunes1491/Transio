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


output privateEndpointId string = privateEndpoint.id
output privateEndpointName string = privateEndpoint.name
output ipAddress string = privateEndpoint.properties.networkInterfaces[0].properties.ipConfigurations[0].properties.privateIPAddress
