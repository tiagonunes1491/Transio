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

@secure()
@description('Application database user name')
param appDatabaseUser string

@description('Application database user password')
@secure()
param appDatabasePassword string

@description('User Assigned Identity ID for deployment script')
param userAssignedIdentityId string

@description('ACA subnet ID for deployment script networking')
param acaSubnetId string

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

// No broad role assignments needed - deployment scripts can run with User Assigned Identity's inherent permissions
// The script only needs to connect to PostgreSQL, which doesn't require Azure RBAC roles

resource createAppUserRole 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: '${serverName}-init-db'
  location: location
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityId}': {}
    }
  }
  properties: {
    azCliVersion: '2.50.0'
    timeout: 'PT15M'
    retentionInterval: 'P1D'
    containerSettings: {
      subnetIds: [
        {
          id: acaSubnetId // Use the ACA subnet for deployment script connectivity
        }
      ]
    }
    environmentVariables: [
      {
        name: 'POSTGRES_SERVER_FQDN'
        value: postgresqlServer.properties.fullyQualifiedDomainName
      }
      {
        name: 'POSTGRES_USER'
        value: administratorLogin
      }
      {
        name: 'POSTGRES_PASSWORD'
        secureValue: administratorLoginPassword
      }
      {
        name: 'POSTGRES_DB'
        value: databaseName
      }
      {
        name: 'APP_DB_USER'
        value: appDatabaseUser
      }
      {
        name: 'APP_DB_PASSWORD'
        secureValue: appDatabasePassword
      }
    ]
    scriptContent: '''
      set -e
      
      echo "Starting database initialization script..."
      
      # Install PostgreSQL client
      apk add --no-cache postgresql-client
      
      # Wait for PostgreSQL to be ready
      echo "Waiting for PostgreSQL server to be available..."
      for i in {1..30}; do
        if pg_isready -h $POSTGRES_SERVER_FQDN -U $POSTGRES_USER -t 5; then
          echo "PostgreSQL is ready!"
          break
        fi
        echo "Attempt $i: PostgreSQL not ready, waiting 10 seconds..."
        sleep 10
      done
      
      # Execute PostgreSQL DDL (same as your init script)
      PGPASSWORD=$POSTGRES_PASSWORD psql -v ON_ERROR_STOP=1 -h $POSTGRES_SERVER_FQDN -U "$POSTGRES_USER" -d "$POSTGRES_DB" <<-EOSQL
        DO \$\$
        BEGIN
          IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '$APP_DB_USER') THEN
            CREATE ROLE "$APP_DB_USER" WITH LOGIN PASSWORD '$APP_DB_PASSWORD';
            RAISE NOTICE 'Created role: $APP_DB_USER';
          ELSE
            ALTER ROLE "$APP_DB_USER" WITH PASSWORD '$APP_DB_PASSWORD';
            RAISE NOTICE 'Updated password for role: $APP_DB_USER';
          END IF;
        END
        \$\$;

        GRANT CONNECT ON DATABASE "$POSTGRES_DB" TO "$APP_DB_USER";
        GRANT USAGE ON SCHEMA public TO "$APP_DB_USER";
        ALTER DEFAULT PRIVILEGES IN SCHEMA public
              GRANT SELECT,INSERT,UPDATE,DELETE ON TABLES TO "$APP_DB_USER";

        REVOKE CREATE ON SCHEMA public FROM PUBLIC;      -- nobody else can create
        ALTER SCHEMA public OWNER TO "$APP_DB_USER";     -- app role becomes owner
        GRANT USAGE,CREATE ON SCHEMA public TO "$APP_DB_USER";
EOSQL
      
      echo "Database initialization script finished."
    '''
    cleanupPreference: 'OnSuccess'  }
  dependsOn: [
    postgresqlDatabase
  ]
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
