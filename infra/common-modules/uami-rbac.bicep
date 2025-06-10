@description('Principal ID of the User-Assigned Managed Identity')
param uamiPrincipalId string

@description('Role definition ID to assign (full resource path)')
param roleDefinitionId string

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(uamiPrincipalId, roleDefinitionId, resourceGroup().id)
  properties: {
    principalId: uamiPrincipalId
    roleDefinitionId: roleDefinitionId
    principalType: 'ServicePrincipal'
  }
}

output roleAssignmentId string = roleAssignment.id
