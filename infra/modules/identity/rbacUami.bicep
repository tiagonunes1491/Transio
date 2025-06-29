/*
 * =============================================================================
 * UAMI RBAC Assignment Module
 * =============================================================================
 * 
 * This Bicep module creates role-based access control (RBAC) assignments for
 * User-Assigned Managed Identities (UAMIs). It provides a simplified way to
 * assign roles to UAMIs with proper scope control and idempotent deployment
 * guarantees through deterministic GUID generation.
 * 
 * ARCHITECTURE OVERVIEW:
 * ┌─────────────────────────────────────────────────────────────────────────┐
 * │                         UAMI RBAC Assignment                            │
 * ├─────────────────────────────────────────────────────────────────────────┤
 * │  Authorization                                                          │
 * │  ┌─────────────────────────────────────────────────────────────────────┐│
 * │  │ Role Assignment                                                     ││
 * │  │ ┌─────────────────────┐  ┌─────────────────────────────────────┐   ││
 * │  │ │ Principal ID        │  │ Role Definition                     │   ││
 * │  │ │ • UAMI identity     │──│ • Built-in or custom role           │   ││
 * │  │ │ • Service Principal │  │ • Subscription scoped               │   ││
 * │  │ └─────────────────────┘  └─────────────────────────────────────┘   ││
 * │  │                                                                     ││
 * │  │ ┌─────────────────────────────────────────────────────────────────┐ ││
 * │  │ │ Assignment Scope                                                │ ││
 * │  │ │ • UAMI resource level                                           │ ││
 * │  │ │ • Deterministic naming for idempotency                          │ ││
 * │  │ └─────────────────────────────────────────────────────────────────┘ ││
 * │  └─────────────────────────────────────────────────────────────────────┘│
 * └─────────────────────────────────────────────────────────────────────────┘
 * 
 * FEATURES:
 * • Idempotent deployments with deterministic GUID generation
 * • Support for both built-in role GUIDs and full role definition IDs
 * • Proper principal type handling for service principals
 * • Scoped assignments at the UAMI resource level
 */

@description('Name of the User-Assigned Managed Identity to scope the assignment to')
param uamiName string

@description('Object ID of the principal (UAMI, SP, AKS, etc.)')
param principalId string

@description('Full roleDefinitionId path or built-in GUID')
param roleDefinitionId string

// Reference the existing UAMI resource
resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: uamiName
}

resource assignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  // Generate deterministic GUID based on principal, role, and UAMI resource ID for idempotent deployments
  name: guid(principalId, roleDefinitionId, uami.id)
  scope: uami  // Use the resource reference, not a string
  properties: {
    principalId: principalId
    // Handle both full resource IDs and role GUIDs
    // If the roleDefinitionId contains '/providers/', treat it as a full resource ID
    // Otherwise, convert the GUID to a subscription-scoped role definition resource ID
    roleDefinitionId: contains(roleDefinitionId, '/providers/') ? roleDefinitionId : subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
    // Principal type is set to ServicePrincipal for UAMIs and Service Principals
    // Note: This works for User Assigned Managed Identities despite the name
    principalType: 'ServicePrincipal'
  }
}

output assignmentId string = assignment.id
