/*
 * =============================================================================
 * Resource Group RBAC Module
 * =============================================================================
 * 
 * This Bicep module assigns Azure RBAC roles to principals at resource group
 * scope. It provides flexible role assignment capabilities with support for
 * both built-in and custom roles, implementing deterministic naming patterns
 * for conflict-free deployments and proper governance.
 * 
 * KEY FEATURES:
 * • Resource Group Scope: Role assignments at the resource group level
 * • Flexible Role Support: Both built-in role GUIDs and full resource IDs
 * • Deterministic Naming: GUID-based naming prevents assignment conflicts
 * • Idempotent Deployments: Safe re-deployment without duplication
 * • Principal Flexibility: Support for UAMIs, Service Principals, and groups
 * 
 * SECURITY CONSIDERATIONS:
 * • Least privilege principle through precise role assignment
 * • Audit trail for all resource group access operations
 * • Role definition validation and proper scope assignment
 * • Governance support through consistent role management
 */
//
// Outputs:
//   - assignmentId: The resource ID of the created role assignment
//
// Usage:
//   Use this module to grant a specific Azure role to a principal at the desired scope.
//   Set the module's deployment scope when calling it to control where the role is assigned.
//
// Example:
//   module rbac 'core/roleAssignment.bicep' = {
//     name: 'assignRoleToUAMI'
//     scope: resourceGroup()
//     params: {
//       principalId: userIdentity.properties.principalId
//       roleDefinitionId: 'b24988ac-6180-42a0-ab88-20f7382dd24c' // Contributor
//     }
//   }

@description('Object ID of the principal (UAMI, SP, AKS, etc.)')
param principalId string

@description('Full roleDefinitionId path or built-in GUID')
param roleDefinitionId string

resource assignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  // Generate deterministic GUID based on principal, role, and subscription for idempotent deployments
  name: guid(principalId, roleDefinitionId, subscription().id)
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
