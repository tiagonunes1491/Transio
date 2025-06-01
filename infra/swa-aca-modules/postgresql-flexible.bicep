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

@description('Storage account name for deployment script artifacts')
param storageAccountName string

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
    timeout: 'PT5M'
    retentionInterval: 'P1D'
    containerSettings: {
      subnetIds: [
        {
          id: acaSubnetId // Use the ACA subnet for deployment script connectivity
        }      ]
    }
    storageAccountSettings: {
      storageAccountName: storageAccountName
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
      # Install PostgreSQL client
      apk add --no-cache postgresql-client
      
      # Secure database initialization
      PGPASSWORD=$POSTGRES_PASSWORD psql -h $POSTGRES_SERVER_FQDN -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "
        -- Remove public schema permissions from everyone
        REVOKE ALL ON SCHEMA public FROM PUBLIC;
        REVOKE ALL ON DATABASE \"$POSTGRES_DB\" FROM PUBLIC;
        
        -- Drop any existing non-system roles (except admin and replication roles)
        DO \$\$
        DECLARE
          role_name TEXT;
        BEGIN
          FOR role_name IN 
            SELECT rolname FROM pg_roles 
            WHERE rolname NOT IN ('$POSTGRES_USER', 'postgres', 'pg_monitor', 'pg_read_all_settings', 
                                  'pg_read_all_stats', 'pg_stat_scan_tables', 'pg_read_server_files',
                                  'pg_write_server_files', 'pg_execute_server_program', 'pg_signal_backend',
                                  'azure_pg_admin', 'azure_superuser', 'replication')
            AND rolname NOT LIKE 'pg_%'
            AND rolname != '$APP_DB_USER'
          LOOP
            EXECUTE 'DROP ROLE IF EXISTS ' || quote_ident(role_name);
          END LOOP;
        END
        \$\$;
        
        -- Create clean application user
        DROP ROLE IF EXISTS \"$APP_DB_USER\";
        CREATE ROLE \"$APP_DB_USER\" WITH LOGIN PASSWORD '$APP_DB_PASSWORD';
        
        -- Grant minimal required permissions to app user only
        GRANT CONNECT ON DATABASE \"$POSTGRES_DB\" TO \"$APP_DB_USER\";
        GRANT USAGE, CREATE ON SCHEMA public TO \"$APP_DB_USER\";
        
        -- Grant table permissions only to app user
        GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO \"$APP_DB_USER\";
        ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO \"$APP_DB_USER\";
        
        -- Grant sequence permissions only to app user
        GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO \"$APP_DB_USER\";
        ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO \"$APP_DB_USER\";
        
        -- Set app user as schema owner for future objects
        ALTER SCHEMA public OWNER TO \"$APP_DB_USER\";
        
        -- Ensure no other roles have access
        ALTER DEFAULT PRIVILEGES FOR ROLE \"$APP_DB_USER\" IN SCHEMA public REVOKE ALL ON TABLES FROM PUBLIC;
        ALTER DEFAULT PRIVILEGES FOR ROLE \"$APP_DB_USER\" IN SCHEMA public REVOKE ALL ON SEQUENCES FROM PUBLIC;
      "
      
      echo "Database secured: Only admin and app user roles exist, no public access"
    '''
    cleanupPreference: 'OnSuccess'
  }
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
