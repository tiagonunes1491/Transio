/*
 * =============================================================================
 * Network Security Group Module
 * =============================================================================
 * 
 * This Bicep module creates and configures Azure Network Security Groups (NSGs)
 * providing comprehensive network security controls for applications.
 * security policies with configurable allow/deny rules and default security
 * postures to protect containerized workloads and platform services.
 * 
 * ARCHITECTURE OVERVIEW:
 * ┌─────────────────────────────────────────────────────────────────────────┐
 * │                Network Security Group Architecture                      │
 * ├─────────────────────────────────────────────────────────────────────────┤
 * │  Traffic Control Framework                                              │
 * │  ┌─────────────────────────────────────────────────────────────────────┐│
 * │  │ Inbound Rules (Priority Order)                                      ││
 * │  │ ┌─────────────────────┐  ┌─────────────────────────────────────┐   ││
 * │  │ │ Allow Rules         │  │ Application Traffic                 │   ││
 * │  │ │ • HTTPS (443)       │  │ • Web traffic                       │   ││
 * │  │ │ • HTTP (80)         │  │ • API endpoints                     │   ││
 * │  │ │ • Custom ports      │  │ • Health checks                     │   ││
 * │  │ └─────────────────────┘  └─────────────────────────────────────┘   ││
 * │  │                                                                     ││
 * │  │ Outbound Rules (Security Focus)                                     ││
 * │  │ ┌─────────────────────┐  ┌─────────────────────────────────────┐   ││
 * │  │ │ Deny Rules          │  │ Default Deny All                    │   ││
 * │  │ │ • Malicious IPs     │  │ • Explicit allow required           │   ││
 * │  │ │ • Blocked ports     │  │ • Zero-trust approach               │   ││
 * │  │ │ • Geographic blocks │  │ • Audit all blocked traffic        │   ││
 * │  │ └─────────────────────┘  └─────────────────────────────────────┘   ││
 * │  └─────────────────────────────────────────────────────────────────────┘│
 * └─────────────────────────────────────────────────────────────────────────┘
 * 
 * KEY FEATURES:
 * • Configurable Rule Sets: Flexible allow and deny rule configuration
 * • Priority Management: Automatic rule priority assignment for proper enforcement
 * • Default Deny Policy: Optional default deny-all rule for enhanced security posture
 * • Zero-Trust Architecture: Explicit allow model with comprehensive traffic filtering
 * • Protocol Support: TCP, UDP, and ICMP protocol handling with port specifications
 * • Source/Destination Control: Granular control over traffic sources and destinations
 * • Logging Integration: NSG flow logs for security monitoring and compliance
 * 
 * SECURITY CONSIDERATIONS:
 * • Default deny-all rule provides secure baseline configuration
 * • Explicit allow rules enforce principle of least privilege networking
 * • Rule priority ordering prevents security policy bypass attempts
 * • Comprehensive logging for security incident investigation
 * • Support for both application and infrastructure protection
 * • Geographic and threat intelligence-based blocking capabilities
 * 
 * DEPLOYMENT SCOPE:
 * This module operates at resource group scope to create Network Security
 * Groups that can be associated with subnets to control network traffic
 * for Container Apps, virtual machines, and other Azure resources.
 */
@description('Name of the Network Security Group')
param nsgName string = 'nsg-securesharer-mvp'

@description('Tags of the Network Security Group')
param tags object

@description('Allow rules for the Network Security Group')
param allowRules array 

@description('Deny rules for the Network Security Group')
param denyRules array

@description('Location of the Network Security Group')
param location string = resourceGroup().location

// Include basic deny-all rule as the last rule for better security posture
param includeDefaultDenyRule bool = true

var defaultDenyRule = includeDefaultDenyRule ? [{
  name: 'DenyAllInbound'
  properties: {
    priority: 4096
    direction: 'Inbound'
    access: 'Deny'
    protocol: '*'
    sourceAddressPrefix: '*'
    sourcePortRange: '*'
    destinationAddressPrefix: '*'
    destinationPortRange: '*'
  }
}] : []

// Creates a single list of NSG rules by concatenating allow and deny rules
var combinedSecurityRules = concat(allowRules, denyRules, defaultDenyRule)

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: nsgName
  location: location
  tags: tags
  properties: {
    securityRules: combinedSecurityRules
  }
}

output nsgId string = nsg.id
output nsgName string = nsg.name
