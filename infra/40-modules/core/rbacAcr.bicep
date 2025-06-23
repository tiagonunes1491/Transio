// Assigns an Azure Container Registry RBAC role to a principal at the registry level.
// This module should be deployed at the same scope where the ACR exists.

@description('Full resource ID of the ACR registry')
param registryId string

@description('Object ID of the principal (UAMI, SP, AKS, etc.)')
param principalId string

@description('Full roleDefinitionId path or built-in GUID of the role to assign')
param roleDefinitionId string

// Parse out registry name from the registryId
var registryName = split(registryId, '/')[8]

// Reference the existing ACR registry in the current resource group
resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: registryName
}

// Apply the role assignment directly to the ACR resource
resource assignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: acr
  name: guid(acr.id, principalId, roleDefinitionId)
  properties: {
    principalId: principalId
    roleDefinitionId: contains(roleDefinitionId, '/providers/')
      ? roleDefinitionId
      : subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
    principalType: 'ServicePrincipal'
  }
}

output assignmentId string = assignment.id
