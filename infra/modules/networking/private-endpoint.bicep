/*
 * =============================================================================
 * Private Endpoint Module for Secure Secret Sharer
 * =============================================================================
 * 
 * This Bicep module creates Azure Private Endpoints for secure, private
 * connectivity to Azure services. It establishes network-isolated connections
 * that bypass the public internet, providing enhanced security for data
 * transmission between the Secure Secret Sharer application and Azure services.
 * 
 * ARCHITECTURE OVERVIEW:
 * ┌─────────────────────────────────────────────────────────────────────────┐
 * │                Private Endpoint Architecture                            │
 * ├─────────────────────────────────────────────────────────────────────────┤
 * │  Virtual Network Integration                                            │
 * │  ┌─────────────────────────────────────────────────────────────────────┐│
 * │  │ Private Endpoint Subnet                                             ││
 * │  │ ┌─────────────────────┐  ┌─────────────────────────────────────┐   ││
 * │  │ │ Private Endpoint    │  │ Network Interface                   │   ││
 * │  │ │ • Private IP        │  │ • Azure backbone routing            │   ││
 * │  │ │ • Service mapping   │  │ • Traffic isolation                 │   ││
 * │  │ │ • DNS integration   │  │ • Secure communication             │   ││
 * │  │ └─────────────────────┘  └─────────────────────────────────────┘   ││
 * │  │                               │                                     ││
 * │  └───────────────────────────────┼─────────────────────────────────────┘│
 * │                                  ▼                                      │
 * │  Azure Service Connection                                               │
 * │  ┌─────────────────────────────────────────────────────────────────────┐│
 * │  │ Target Azure Services                                               ││
 * │  │ ┌─────────────────────┐  ┌─────────────────────────────────────┐   ││
 * │  │ │ Key Vault           │  │ Cosmos DB                           │   ││
 * │  │ │ • Secrets access    │  │ • Database connectivity             │   ││
 * │  │ │ • Certificate mgmt  │  │ • Document operations               │   ││
 * │  │ │ • HSM operations    │  │ • Query processing                  │   ││
 * │  │ └─────────────────────┘  └─────────────────────────────────────┘   ││
 * │  │                                                                     ││
 * │  │ DNS Resolution                                                      ││
 * │  │ ┌─────────────────────┐  ┌─────────────────────────────────────┐   ││
 * │  │ │ Private DNS Zones   │  │ Name Resolution                     │   ││
 * │  │ │ • Service mapping   │  │ • FQDN to private IP               │   ││
 * │  │ │ • Zone linking      │  │ • Conditional forwarding            │   ││
 * │  │ │ • Record management │  │ • Automatic registration            │   ││
 * │  │ └─────────────────────┘  └─────────────────────────────────────┘   ││
 * │  └─────────────────────────────────────────────────────────────────────┘│
 * └─────────────────────────────────────────────────────────────────────────┘
 * 
 * KEY FEATURES:
 * • Network Isolation: Traffic flows through Azure backbone instead of public internet
 * • DNS Integration: Automatic private DNS zone configuration for service resolution
 * • Service Group Support: Flexible targeting of specific Azure service sub-resources
 * • Multi-Zone Support: Connection to multiple private DNS zones for comprehensive resolution
 * • Flexible Configuration: Support for various Azure service types and configurations
 * • Security Enhancement: Eliminates public endpoint exposure for sensitive services
 * • Performance Optimization: Reduced latency through backbone network routing
 * 
 * SECURITY CONSIDERATIONS:
 * • Eliminates public internet exposure for Azure service connectivity
 * • Network traffic isolation through Azure backbone infrastructure
 * • Private IP address assignment within customer virtual network
 * • DNS security through private zone resolution and conditional forwarding
 * • Access control through network security groups and subnet restrictions
 * • Audit logging for all private endpoint connections and usage
 * • Compliance support for data residency and network isolation requirements
 * 
 * DEPLOYMENT SCOPE:
 * This module operates at resource group scope to create private endpoints
 * that can securely connect virtual network resources to Azure services
 * without exposing traffic to the public internet.
 */
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
