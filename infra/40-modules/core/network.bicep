// Virtual Network configuration
// Creates VNet with configurable subnets for Azure services
@description('Name of the virtual network')
param vnetName string

@description('Location for all the resources')
param location string

@description('Tags to apply to all resources')
param tags object = {}

@description('Address space for the virtual network')
param addressSpace array = [
  '10.0.0.0/16'
]

@description('Subnets for the virtual network')
param subnets array = [
  {
    name: 'subnet1'
    addressPrefix: '10.0.1.0/24'
    networkSecurityGroupId: null
  }
]

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: addressSpace
    }
    subnets: [
      for subnet in subnets: {
        name: subnet.name
        properties: {
          addressPrefix: subnet.addressPrefix
          networkSecurityGroup: !empty(subnet.?networkSecurityGroupId) ? { 
            id: subnet.networkSecurityGroupId 
          } : null
          delegations: subnet.?delegations
          privateEndpointNetworkPolicies: subnet.?privateEndpointNetworkPolicies
          serviceEndpoints: subnet.?serviceEndpoints
        }
      }
    ]
  }
}

output vnetId string = vnet.id
output subnetIds array = [
  for subnet in subnets: '${vnet.id}/subnets/${subnet.name}'
]
