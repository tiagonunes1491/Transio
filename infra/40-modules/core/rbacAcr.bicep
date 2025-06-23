// Assigns an Azure Container Registry RBAC role to a principal at the registry level.

@description('Full resource ID of the ACR registry')
param registryId string

@description('Object ID of the principal (UAMI, SP, AKS, etc.)')
param principalId string

@description('Full roleDefinitionId path or built-in GUID of the role to assign')
param roleDefinitionId string

// Parse resource group and registry name
var segments      = split(registryId, '/')
var registryRg    = segments[4]
var registryName  = segments[8]

// Reference the existing ACR registry
resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  scope: resourceGroup(registryRg)
  name : registryName
}

// Apply the role assignment as an extension resource on the registry
resource assignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, principalId, roleDefinitionId)
  properties: {
    principalId     : principalId
    roleDefinitionId: contains(roleDefinitionId, '/providers/')
      ? roleDefinitionId
      : subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
    principalType   : 'ServicePrincipal'
  }
}

output assignmentId string = assignment.id
