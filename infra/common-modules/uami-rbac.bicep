@description('Principal ID of the UAMI')
param uamiPrincipalId string


@description('Role definition ID for the RBAC assignment')
param roleDefinitionId string

@description('Description of the RBAC assignment')
param roleAssignmentDescription string = 'RBAC assignment for UAMI'

// Create the full role definition resource ID
var roleDefinitionResourceId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)


// Assign role to the UAMI

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(uamiPrincipalId, roleDefinitionId, deployment().name)
  properties: {
    roleDefinitionId: roleDefinitionResourceId
    principalId: uamiPrincipalId
    principalType: 'ServicePrincipal'
    description: roleAssignmentDescription
  }
}

// Outputs for the role assignment

output roleAssignmentId string = roleAssignment.id
output roleAssignmentName string = roleAssignment.name
