/*
 * =============================================================================
 * Private DNS Zone Module for Secure Secret Sharer
 * =============================================================================
 * 
 * This Bicep module creates Azure Private DNS Zones and Virtual Network links
 * for private endpoint name resolution. It enables secure DNS resolution for
 * private endpoints, ensuring that Azure service FQDNs resolve to private
 * IP addresses within the virtual network environment.
 * 
 * KEY FEATURES:
 * • Private DNS Zones: Creates DNS zones for Azure service private endpoint resolution
 * • VNet Link Integration: Automatic virtual network linking for DNS resolution
 * • Global Scope: DNS zones deployed globally for consistent resolution
 * • Service Integration: Support for Key Vault, Storage, Cosmos DB, and other services
 * • Automatic Registration: Enables automatic private endpoint DNS record registration
 * 
 * SECURITY CONSIDERATIONS:
 * • Private name resolution prevents DNS leakage to public resolvers
 * • Network isolation through private DNS resolution
 * • Secure service discovery within virtual network boundaries
 * • Protection against DNS hijacking and manipulation attacks
 */
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
