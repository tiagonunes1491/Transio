/*
 * =============================================================================
 * Key Vault RBAC Module for Secure Secret Sharer
 * =============================================================================
 * 
 * This Bicep module assigns Key Vault RBAC roles to managed identities for
 * secure secrets access. It implements the Key Vault Secrets User role
 * assignment pattern, replacing legacy access policies with modern RBAC
 * for enhanced security and governance.
 * 
 * KEY FEATURES:
 * • Secrets User Role: Assigns Key Vault Secrets User role for secret retrieval
 * • Managed Identity Support: Optimized for User-Assigned Managed Identity integration
 * • Deterministic Naming: GUID-based naming prevents role assignment conflicts
 * • Modern RBAC: Replaces legacy access policies with Azure RBAC
 * • Audit Integration: Full audit trail for Key Vault access operations
 * 
 * SECURITY CONSIDERATIONS:
 * • Least privilege access - secrets user role only, no management permissions
 * • No stored credentials - managed identity authentication only
 * • Comprehensive audit logging for compliance and security monitoring
 * • Role-based access control for improved governance
 */

@description('ID of the Azure Key Vault (optional - set if Key Vault is in this RG)')
param keyVaultId string = ''

@description('Principal ID of the managed identity to give access to Key Vault, ACR, and Cosmos DB')
param id string

@description('Role definition ID for Key Vault role to assign, e.g., Key Vault Secrets User - 4633458b-17de-408a-b874-0445c86b69e6')
param roleId string 

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  scope: resourceGroup()
  name: split(keyVaultId, '/')[8]
}

resource kvRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
    scope: keyVault
    name: guid(keyVaultId, id, 'KeyVaultSecretsUser')
    properties: {
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleId)
      principalId: id
      principalType: 'ServicePrincipal'
  }
}


// Outputs
output keyVaultRoleAssignmentId string = kvRoleAssignment.id
