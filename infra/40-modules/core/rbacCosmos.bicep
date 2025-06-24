// Module for assigning Cosmos DB SQL roles within the target resource group
// This module should be deployed at the same scope where the Cosmos DB account exists.

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
