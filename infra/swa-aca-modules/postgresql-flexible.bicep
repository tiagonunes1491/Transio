@description('Name of the PostgreSQL Flexible Server.')
param serverName string

@description('Location for the server.')
param location string

@description('The administrator login username for the server.')
param administratorLogin string

@description('The administrator login password. This should be a secure string.')
@secure()
param administratorLoginPassword string

@description('The SKU name of the server. e.g., Standard_B1ms, Standard_D2s_v3.')
param skuName string

@description('The compute tier of the server. e.g., Burstable, GeneralPurpose, MemoryOptimized.')
param skuTier string

@description('The version of PostgreSQL.')
param postgresVersion string // e.g., '15', '16'

@description('The ID of the subnet to integrate the server with.')
param delegatedSubnetId string

@description('The name of the initial database to create.')
param databaseName string

@description('Tags for the server.')
param tags object = {}

@description('The ARM resource ID of the private DNS zone for PostgreSQL.')
param privateDnsZoneId string

@description('ID of the Log Analytics workspace to send diagnostics to.')
param logAnalyticsWorkspaceId string

resource postgresqlServer 'Microsoft.DBforPostgreSQL/flexibleServers@2024-08-01' = {
  name: serverName
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: skuTier
  }
  properties: {
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
    version: postgresVersion
    storage: {
      storageSizeGB: 32 // Default size, can be adjusted as needed
    }
    highAvailability: {
      mode: 'Disabled' // Adjust based on requirements
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
    network: {
      delegatedSubnetResourceId: delegatedSubnetId
      publicNetworkAccess: 'Disabled' // For private access only
      privateDnsZoneArmResourceId: privateDnsZoneId 
    }
  }
}

resource postgresqlDatabase 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2024-08-01' = {
  name: databaseName
    properties: {
    charset: 'UTF8'      // Common charset
    collation: 'en_US.utf8' // Common collation
  }
  parent: postgresqlServer
}

resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'postgresqlDiagnosticSettings'
  scope: postgresqlServer
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'PostgreSQLLogs'
        enabled: true
        retentionPolicy: {
          enabled: false // Retention managed by Log Analytics workspace
          days: 0
        }
      }
    ]
  }
}

output serverId string = postgresqlServer.id
output serverName string = postgresqlServer.name
output databaseId string = postgresqlDatabase.id
output databaseName string = postgresqlDatabase.name
output fullyQualifiedDomainName string = postgresqlServer.properties.fullyQualifiedDomainName
