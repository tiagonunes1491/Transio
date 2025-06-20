@description('Name of the Cosmos DB account')
param cosmosDbAccountName string

@description('Location for the Cosmos DB account')
param location string

@description('The names of the databases to create')
param databaseNames array = [ 'swa-dev', 'swa-prod', 'k8s-dev', 'k8s-prod' ]

@description('The name of the container to create in each database')
param containerName string = 'secret'

@description('Tags for the Cosmos DB account')
param tags object = {}

@description('Default TTL for documents in seconds (24 hours = 86400)')
param defaultTtl int = 86400

@description('Enable free tier (only one per subscription)')
param enableFreeTier bool = true

@description('Throughput for the container (minimum 400 RU/s)')
param throughput int = 400

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
    enableFreeTier: enableFreeTier
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

resource cosmosDbDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2023-04-15' = [for dbName in databaseNames: {
  name: dbName
  parent: cosmosDbAccount
  properties: {
    resource: {
      id: dbName
    }
  }
}]

resource cosmosDbContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2023-04-15' = [for (dbName, i) in databaseNames: {
  name: containerName
  parent: cosmosDbDatabase[i]
  properties: {
    resource: {
      id: containerName
      partitionKey: {
        paths: [ '/link_id' ]
        kind: 'Hash'
      }
      defaultTtl: defaultTtl
      indexingPolicy: {
        indexingMode: 'consistent'
        includedPaths: [ { path: '/*' } ]
        excludedPaths: [ { path: '/"_etag"/?' } ]
      }
    }
    options: {
      autoscaleSettings: {
        maxThroughput: throughput
      }
    }
  }
}]

output cosmosDbAccountName string = cosmosDbAccount.name
output cosmosDbAccountId string = cosmosDbAccount.id
output cosmosDbEndpoint string = cosmosDbAccount.properties.documentEndpoint
output databaseNames array = [for dbName in databaseNames: dbName]
output containerName string = containerName
