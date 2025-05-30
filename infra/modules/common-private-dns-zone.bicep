@description('Private DNS Zone name')
param privateDnsZoneName string
@description('Virtual Network ID for the Private DNS Zone link')
param vnetId string
@description('Private DNS Zone tags')
param privateDnsZoneTags object = {}
@description('Private DNS Zone records to create')
param privateDnsRecords array = []

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: privateDnsZoneName
  location: 'global'
  tags: privateDnsZoneTags
  properties: {}
}

resource privateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  name: 'link-to-vnet'
  parent: privateDnsZone
  location: 'global'
  properties: {
    virtualNetwork: {
      id: vnetId
    }
    registrationEnabled: false
  }
}

resource privateDnsRecordsResource 'Microsoft.Network/privateDnsZones/A@2024-06-01' = [for record in privateDnsRecords: {
  name: record.name
  parent: privateDnsZone
  properties: {
    ttl: record.ttl
    aRecords: [
      {
        ipv4Address: record.ipv4Address
      }
    ]
  }
}]
