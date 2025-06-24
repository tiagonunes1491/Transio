/*
 * =============================================================================
 * Cosmos DB RBAC Module for Secure Secret Sharer
 * =============================================================================
 * 
 * This Bicep module assigns Cosmos DB SQL roles to principals for secure
 * database access. It supports both account-level and database-scoped role
 * assignments with proper RBAC governance for NoSQL database operations
 * in the Secure Secret Sharer application.
 * 
 * KEY FEATURES:
 * • SQL Role Assignment: Native Cosmos DB SQL role assignment support
 * • Flexible Scoping: Account-level or database-scoped role assignments
 * • Principal Support: Works with UAMIs, Service Principals, and other identities
 * • Deterministic Naming: Conflict-free role assignment creation
 * • Built-in Role Support: Standard Cosmos DB roles (Reader, Contributor, etc.)
 * 
 * SECURITY CONSIDERATIONS:
 * • Least privilege access through precise role and scope assignment
 * • Database-level access control for sensitive data protection
 * • Audit trail for all database access operations
 * • Role-based access control replacing connection string authentication
 */

@description('Name of the Cosmos DB account')
param accountName string

@description('Object ID of the principal (UAMI, SP, AKS, etc.)')
param principalId string

@description('Full roleDefinitionId path or GUID of the Cosmos DB SQL role to assign')
param roleDefinitionId string

@description('Optional database name to scope the role assignment to (leave empty for account-level)')
param databaseName string = ''

// Reference existing Cosmos DB account in the current resource group
resource account 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' existing = {
  name: accountName
}

// SQL role assignment under the Cosmos account
resource sqlRole 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2023-04-15' = {
  parent: account
  name: guid(account.id, principalId, roleDefinitionId, databaseName)
  properties: {
    roleDefinitionId: contains(roleDefinitionId, '/providers/')
      ? roleDefinitionId
      : '${account.id}/sqlRoleDefinitions/${roleDefinitionId}'
    principalId: principalId
    scope: empty(databaseName)
      ? account.id
      : '${account.id}/dbs/${databaseName}'
  }
}

output assignmentId string = sqlRole.id
