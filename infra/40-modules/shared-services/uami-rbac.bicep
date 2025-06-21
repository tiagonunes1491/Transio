// RBAC role assignment for User Assigned Managed Identity
// Assigns Azure roles to UAMIs for resource access at any scope
@description('Principal ID of the User-Assigned Managed Identity')
param uamiPrincipalId string

@description('Role definition ID to assign (full resource path)')
param roleDefinitionId string

@description('Scope for the role assignment (resource ID, resource group ID, etc.)')
param scope string = resourceGroup().id

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(uamiPrincipalId, roleDefinitionId, scope)
  properties: {
    principalId: uamiPrincipalId
    roleDefinitionId: roleDefinitionId
    principalType: 'ServicePrincipal'
  }
}

output roleAssignmentId string = roleAssignment.id
