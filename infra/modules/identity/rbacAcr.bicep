/*
 * =============================================================================
 * ACR RBAC Module for Secure Secret Sharer
 * =============================================================================
 * 
 * This Bicep module assigns Azure Container Registry RBAC roles to principals
 * at the registry level. It implements least-privilege access control for
 * container image operations, supporting pull, push, and administrative
 * permissions with deterministic role assignment naming.
 * 
 * KEY FEATURES:
 * • Registry-Level RBAC: Precise permission assignment at the ACR resource level
 * • Multiple Principal Support: Works with UAMIs, Service Principals, and AKS clusters
 * • Deterministic Naming: Prevents conflicts through GUID-based assignment names
 * • Built-in Role Support: Supports standard ACR roles (AcrPull, AcrPush, etc.)
 * • Idempotent Deployment: Safe re-deployment without role assignment duplication
 * 
 * SECURITY CONSIDERATIONS:
 * • Principle of least privilege through specific role assignments
 * • No credential storage - uses managed identity authentication
 * • Audit trail for all registry access operations
 * • Role separation between pull and push operations
 */

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
    roleDefinitionId: contains(roleDefinitionId, '/providers/') ? roleDefinitionId : subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
    principalType: 'ServicePrincipal'
  }
}

output assignmentId string = assignment.id
