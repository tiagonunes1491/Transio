/*
 * =============================================================================
 * Virtual Network RBAC Assignment Module
 * =============================================================================
 * 
 * This Bicep module creates role-based access control (RBAC) assignments for
 * Azure Virtual Networks. It provides a standardized way to assign permissions
 * to managed identities, service principals, or users for network resource
 * management with proper scope control and idempotent deployments.
 * 
 * ARCHITECTURE OVERVIEW:
 * ┌─────────────────────────────────────────────────────────────────────────┐
 * │                     Virtual Network RBAC Assignment                     │
 * ├─────────────────────────────────────────────────────────────────────────┤
 * │  Azure Authorization                                                    │
 * │  ┌─────────────────────────────────────────────────────────────────────┐│
 * │  │ Role Assignment                                                     ││
 * │  │ ┌─────────────────────┐  ┌─────────────────────────────────────┐   ││
 * │  │ │ Principal Identity  │  │ Role Definition                     │   ││
 * │  │ │ • Managed Identity  │──│ • Network Contributor               │   ││
 * │  │ │ • Service Principal │  │ • Custom networking roles          │   ││
 * │  │ │ • User identity     │  │ • Built-in role permissions        │   ││
 * │  │ └─────────────────────┘  └─────────────────────────────────────┘   ││
 * │  └─────────────────────────────────────────────────────────────────────┘│
 * │                                                                         │
 * │  Virtual Network Scope                                                  │
 * │  ┌─────────────────────────────────────────────────────────────────────┐│
 * │  │ • VNet-level permissions                                            ││
 * │  │ • Subnet management access                                          ││
 * │  │ • Network security group operations                                 ││
 * │  │ • Route table management                                            ││
 * │  └─────────────────────────────────────────────────────────────────────┘│
 * └─────────────────────────────────────────────────────────────────────────┘
 * 
 * COMMON ROLE ASSIGNMENTS:
 * • Network Contributor: Full network resource management
 * • Virtual Machine Contributor: VM network interface management  
 * • Custom roles: Specific networking permissions
 */

@description('VNet resource ID')
param vnetId string

@description('Principal to assign')
param principalId string

@description('RoleDefinition GUID or full ID')
param roleDefinitionId string

resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' existing = {
  scope: resourceGroup()
  name: split(vnetId, '/')[8]
}

resource assignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: vnet
  name: guid(vnet.id, principalId, roleDefinitionId)
  properties: {
    principalId: principalId
    roleDefinitionId: contains(roleDefinitionId, '/providers/')
      ? roleDefinitionId
      : subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
    principalType: 'ServicePrincipal'
  }
}

output assignmentId string = assignment.id
