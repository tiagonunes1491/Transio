@description('Principal ID of the User-Assigned Managed Identity')
param uamiPrincipalId string

@description('Role definition ID to assign')
param roleDefinitionId string

@description('Scope where the role should be assigned')
param scope string

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(uamiPrincipalId, roleDefinitionId, scope)
  properties: {
    principalId: uamiPrincipalId
    roleDefinitionId: roleDefinitionId
    principalType: 'ServicePrincipal'
  }
}

output roleAssignmentId string = roleAssignment.id
