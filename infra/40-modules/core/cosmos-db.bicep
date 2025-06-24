// Azure Cosmos DB configuration
// Creates Cosmos DB account with configurable databases and containers
@description('Name of the Cosmos DB account')
param cosmosDbAccountName string

@description('Location for the Cosmos DB account')
param location string

@description('Tags for the Cosmos DB account')
param tags object = {}

@description('Consistency level for the Cosmos DB account')
@allowed([
  'BoundedStaleness'
  'Eventual'
  'Session'
  'Strong'
  'ConsistentPrefix'
])
param consistencyLevel string = 'Session'

@description('Enable free tier (only one per subscription)')
param enableFreeTier bool = false

@description('Enable automatic failover')
param enableAutomaticFailover bool = false

@description('Enable multiple write locations')
param enableMultipleWriteLocations bool = false

@description('Enable zone redundancy for the primary location')
param enableZoneRedundancy bool = false

@description('Backup policy configuration')
param backupPolicy object = {
  type: 'Periodic'
  periodicModeProperties: {
    backupIntervalInMinutes: 240
    backupRetentionIntervalInHours: 8
    backupStorageRedundancy: 'Local'
  }
}

@description('Public network access setting')
@allowed([
  'Enabled'
  'Disabled'
  'SecuredByPerimeter'
])
param publicNetworkAccess string = 'Enabled'


@description('Database configurations with optional containers')
@metadata({
  example: [
    {
      name: 'myDatabase'
      throughput: 400 // optional - manual throughput
      autoscaleSettings: { maxThroughput: 4000 } // optional - autoscale instead of manual
      containers: [
        {
          name: 'myContainer'
          partitionKey: { paths: ['/id'], kind: 'Hash' }
          defaultTtl: 3600 // optional
          throughput: 400 // optional - manual throughput
          autoscaleSettings: { maxThroughput: 4000 } // optional - autoscale instead of manual
          indexingPolicy: { // optional
            indexingMode: 'consistent'
            includedPaths: [{ path: '/*' }]
            excludedPaths: [{ path: '/"_etag"/?' }]
          }
        }
      ]
    }
  ]
})
param databases array = []


resource cosmosDbAccount 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' = {
  name: cosmosDbAccountName
  location: location
  kind: 'GlobalDocumentDB'
  tags: tags
  properties: {
    consistencyPolicy: {
      defaultConsistencyLevel: consistencyLevel
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: enableZoneRedundancy
      }
    ]
    databaseAccountOfferType: 'Standard'
    enableAutomaticFailover: enableAutomaticFailover
    enableMultipleWriteLocations: enableMultipleWriteLocations
    enableFreeTier: enableFreeTier
    publicNetworkAccess: publicNetworkAccess
    backupPolicy: backupPolicy
  }
}

resource cosmosDbDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2023-04-15' = [for database in databases: {
  name: database.name
  parent: cosmosDbAccount
  properties: {
    resource: {
      id: database.name
    }
    options: contains(database, 'throughput') ? {
      throughput: database.throughput
    } : contains(database, 'autoscaleSettings') ? {
      autoscaleSettings: database.autoscaleSettings
    } : {}
  }
}]

// Create containers using nested loops for each database
resource cosmosDbContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2023-04-15' = [for i in range(0, length(databases)): if(contains(databases[i], 'containers')) {
  name: databases[i].containers[0].name
  parent: cosmosDbDatabase[i]
  properties: {
    resource: {
      id: databases[i].containers[0].name
      partitionKey: databases[i].containers[0].partitionKey
      defaultTtl: databases[i].containers[0].?defaultTtl
      indexingPolicy: databases[i].containers[0].?indexingPolicy ?? {
        indexingMode: 'consistent'
        includedPaths: [ { path: '/*' } ]
        excludedPaths: [ { path: '/"_etag"/?' } ]
      }
    }
    options: contains(databases[i].containers[0], 'throughput') ? {
      throughput: databases[i].containers[0].throughput
    } : contains(databases[i].containers[0], 'autoscaleSettings') ? {
      autoscaleSettings: databases[i].containers[0].autoscaleSettings
    } : {}
  }
}]

output cosmosDbAccountName string = cosmosDbAccount.name
output cosmosDbAccountId string = cosmosDbAccount.id
output cosmosDbEndpoint string = cosmosDbAccount.properties.documentEndpoint
output databases array = [for database in databases: {
  name: database.name
  containers: database.?containers ?? []
}]
