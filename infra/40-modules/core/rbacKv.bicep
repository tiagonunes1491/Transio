// Assigns an Azure Key Vault RBAC role to a principal at the Key Vault resource level.

@description('Full resource ID of the Key Vault')
param vaultId string

@description('Object ID of the principal (UAMI, SP, AKS, etc.)')
param principalId string

@description('Full roleDefinitionId path or built-in GUID of the role to assign')
param roleDefinitionId string

// Parse out the resource group and vault name from the vaultId
var segments = split(vaultId, '/')
var vaultRg   = segments[4]
var vaultName = segments[8]

// Reference the existing Key Vault
resource kv 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  scope: resourceGroup(vaultRg)
  name: vaultName
}

// Apply the role assignment as an extension resource on the KV
resource assignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(kv.id, principalId, roleDefinitionId)
  properties: {
    principalId     : principalId
    roleDefinitionId: contains(roleDefinitionId, '/providers/')
      ? roleDefinitionId
      : subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
    principalType   : 'ServicePrincipal'
  }
}

output assignmentId string = assignment.id
  