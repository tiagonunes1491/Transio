@description('Name of the Cosmos DB account')
param cosmosDbAccountName string

@description('Location for the Cosmos DB account')
param location string

@description('The name of the database to create')
param databaseName string

@description('The name of the container to create')
param containerName string

@description('Tags for the Cosmos DB account')
param tags object = {}

@description('Default TTL for documents in seconds (24 hours = 86400)')
param defaultTtl int = 86400

@description('Principal IDs of managed identities that need access to Cosmos DB')
param managedIdentityPrincipalIds array = []

// Built-in role definition IDs for Cosmos DB
var cosmosDbDataContributorRoleId = '00000000-0000-0000-0000-000000000002' // Cosmos DB Built-in Data Contributor

resource cosmosDbAccount 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' = {
  name: cosmosDbAccountName
  location: location
  kind: 'GlobalDocumentDB'
  tags: tags
  properties: {
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    databaseAccountOfferType: 'Standard'
    enableAutomaticFailover: false
    enableMultipleWriteLocations: false
    capabilities: [
      {
        name: 'EnableServerless' // Use serverless for cost efficiency
      }
    ]
    backupPolicy: {
      type: 'Periodic'
      periodicModeProperties: {
        backupIntervalInMinutes: 240
        backupRetentionIntervalInHours: 8
        backupStorageRedundancy: 'Local'
      }
    }
  }
}

resource cosmosDbDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2023-04-15' = {
  name: databaseName
  parent: cosmosDbAccount
  properties: {
    resource: {
      id: databaseName
    }
  }
}

resource cosmosDbContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2023-04-15' = {
  name: containerName
  parent: cosmosDbDatabase
  properties: {
    resource: {
      id: containerName
      partitionKey: {
        paths: [
          '/link_id'
        ]
        kind: 'Hash'
      }
      defaultTtl: defaultTtl
      indexingPolicy: {
        indexingMode: 'consistent'
        includedPaths: [
          {
            path: '/*'
          }
        ]
        excludedPaths: [
          {
            path: '/"_etag"/?'
          }
        ]
      }
    }
  }
}

// Assign Cosmos DB Data Contributor role to managed identities
resource cosmosDbRoleAssignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2023-04-15' = [for (principalId, i) in managedIdentityPrincipalIds: {
  name: guid(cosmosDbAccount.id, principalId, cosmosDbDataContributorRoleId)
  parent: cosmosDbAccount
  properties: {
    roleDefinitionId: '${cosmosDbAccount.id}/sqlRoleDefinitions/${cosmosDbDataContributorRoleId}'
    principalId: principalId
    scope: cosmosDbAccount.id
  }
}]

output cosmosDbAccountName string = cosmosDbAccount.name
output cosmosDbAccountId string = cosmosDbAccount.id
output cosmosDbEndpoint string = cosmosDbAccount.properties.documentEndpoint
output databaseName string = cosmosDbDatabase.name
output containerName string = cosmosDbContainer.name