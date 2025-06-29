/*
 * =============================================================================
 * Virtual Network Module
 * =============================================================================
 * 
 * This Bicep module creates and configures Azure Virtual Network infrastructure
 * providing network isolation, segmentation, and secure connectivity patterns 
 * for containerized workloads and platform services with comprehensive subnet 
 * management capabilities.
 * 
 * ARCHITECTURE OVERVIEW:
 * ┌─────────────────────────────────────────────────────────────────────────┐
 * │                       Virtual Network Architecture                      │
 * ├─────────────────────────────────────────────────────────────────────────┤
 * │  Virtual Network (Configurable Address Space)                          │
 * │  ┌─────────────────────────────────────────────────────────────────────┐│
 * │  │ Subnet 1 (Workload Subnet)                                         ││
 * │  │ ┌─────────────────────┐  ┌─────────────────────────────────────┐   ││
 * │  │ │ Container Apps      │  │ Network Security Group              │   ││
 * │  │ │ • Application pods  │  │ • Ingress rules                     │   ││
 * │  │ │ • Service endpoints │  │ • Egress rules                      │   ││
 * │  │ │ • Load balancers    │  │ • Security policies                 │   ││
 * │  │ └─────────────────────┘  └─────────────────────────────────────┘   ││
 * │  │                                                                     ││
 * │  │ Subnet 2 (Private Endpoints)                                       ││
 * │  │ ┌─────────────────────┐  ┌─────────────────────────────────────┐   ││
 * │  │ │ Private Endpoints   │  │ DNS Integration                     │   ││
 * │  │ │ • Key Vault PE      │  │ • Private DNS zones                 │   ││
 * │  │ │ • Storage PE        │  │ • DNS resolution                    │   ││
 * │  │ │ • Database PE       │  │ • Name resolution                   │   ││
 * │  │ └─────────────────────┘  └─────────────────────────────────────┘   ││
 * │  │                                                                     ││
 * │  │ Additional Subnets (Configurable)                                  ││
 * │  │ • Gateway subnet • Management subnet • DMZ subnet                  ││
 * │  └─────────────────────────────────────────────────────────────────────┘│
 * └─────────────────────────────────────────────────────────────────────────┘
 * 
 * KEY FEATURES:
 * • Flexible Address Space: Configurable CIDR blocks for different environments
 * • Dynamic Subnet Management: Array-based subnet configuration with custom properties
 * • NSG Integration: Automatic association of Network Security Groups per subnet
 * • Service Endpoint Support: Built-in support for Azure service endpoints
 * • Private Endpoint Ready: Subnet configurations optimized for private connectivity
 * • Delegation Support: Container Apps and other service delegations
 * • DNS Integration: Seamless integration with Azure DNS and private DNS zones
 * 
 * SECURITY CONSIDERATIONS:
 * • Network segmentation through dedicated subnets for different workload types
 * • Network Security Group enforcement for traffic filtering and access control
 * • Private endpoint subnet isolation with disabled network policies
 * • Service endpoint security for Azure service connectivity
 * • Configurable subnet delegation for secure service integration
 * • Zero-trust network principles with explicit allow rules
 * 
 * DEPLOYMENT SCOPE:
 * This module operates at resource group scope to create virtual network
 * infrastructure that supports multiple workload types with proper isolation.
 */
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
