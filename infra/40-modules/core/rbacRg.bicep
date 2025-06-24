// Module: core/roleAssignment.bicep
// Description: Assigns an Azure RBAC role to a principal (User Assigned Managed Identity, Service Principal, AKS, etc.) at the module's deployment scope.
// Creates role assignments with deterministic names to prevent conflicts and enable idempotent deployments.
// Supports both built-in role GUIDs and full role definition resource IDs for maximum flexibility.
//
// Parameters:
//   - principalId: Object ID of the principal to assign the role to (UAMI, Service Principal, etc.)
//   - roleDefinitionId: Full roleDefinitionId path or GUID of the built-in role to assign
//
// Role Definition Handling:
//   - If roleDefinitionId contains '/providers/', it's treated as a full resource ID
//   - Otherwise, it's treated as a GUID and converted to a full subscription-scoped resource ID
//   - Supports both built-in and custom role definitions
//
// Resources Created:
//   - Microsoft.Authorization/roleAssignments: Creates the role assignment with a deterministic GUID name
//
// Naming Strategy:
//   - Uses guid(principalId, roleDefinitionId, subscription().id) for deterministic naming
//   - Ensures idempotent deployments and prevents duplicate role assignments
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
    roleDefinitionId: contains(roleDefinitionId, '/providers/')
      ? roleDefinitionId
      : subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
    // Principal type is set to ServicePrincipal for UAMIs and Service Principals
    // Note: This works for User Assigned Managed Identities despite the name
    principalType: 'ServicePrincipal'
  }
}

output assignmentId string = assignment.id
