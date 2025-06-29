@description('Full resource ID of the Application Gateway')
param appGwId string

@description('Object ID of the principal (UAMI, SP, AKS, etc.)')
param principalId string

@description('Full roleDefinitionId path or built-in GUID of the role to assign')
param roleDefinitionId string


resource appGw 'Microsoft.Network/applicationGateways@2023-05-01' existing = {
  scope: resourceGroup()
  name: split(appGwId, '/')[8]
}

resource assignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: appGw
  name: guid(appGw.id, principalId, roleDefinitionId)
  properties: {
    principalId: principalId
    roleDefinitionId: contains(roleDefinitionId, '/providers/')
      ? roleDefinitionId
      : subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
    principalType: 'ServicePrincipal'
  }
}

output assignmentId string = assignment.id
