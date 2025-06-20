// Network Security Group configuration for AKS
// Creates and configures NSG rules for AKS networking
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
