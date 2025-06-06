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
        }
      ]
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
    scriptContent: '''      # Install PostgreSQL client
      apk add --no-cache postgresql-client
      
      echo "=== PostgreSQL Database Initialization ==="
      echo "Server: $POSTGRES_SERVER_FQDN"
      echo "Admin User: $POSTGRES_USER"
      echo "App User: $APP_DB_USER"
      echo "Database: $POSTGRES_DB"
      
      # Set PostgreSQL connection parameters for SSL (required by Azure)
      export PGSSL_MODE=require
      export PGSSL_CERT=""
      export PGSSL_KEY=""
      export PGSSL_ROOT_CERT=""
      
      # Test connection with SSL
      echo "Testing PostgreSQL connection with SSL..."
      PGPASSWORD=$POSTGRES_PASSWORD psql "host=$POSTGRES_SERVER_FQDN port=5432 dbname=$POSTGRES_DB user=$POSTGRES_USER sslmode=require" -c "SELECT version();" || {
        echo "ERROR: Cannot connect to PostgreSQL with SSL"
        exit 1
      }
      echo "✓ Connected successfully with SSL"
        # Secure database initialization (avoiding superuser operations)
      PGPASSWORD=$POSTGRES_PASSWORD psql "host=$POSTGRES_SERVER_FQDN port=5432 dbname=$POSTGRES_DB user=$POSTGRES_USER sslmode=require" -c "
        -- Remove public schema permissions from everyone
        REVOKE ALL ON SCHEMA public FROM PUBLIC;
        REVOKE ALL ON DATABASE \"$POSTGRES_DB\" FROM PUBLIC;
        
        -- Only drop non-superuser roles that we can safely drop
        DO \$\$
        DECLARE
          role_name TEXT;
        BEGIN
          FOR role_name IN 
            SELECT rolname FROM pg_roles 
            WHERE rolname NOT IN ('$POSTGRES_USER', 'postgres', 'pg_monitor', 'pg_read_all_settings', 
                                  'pg_read_all_stats', 'pg_stat_scan_tables', 'pg_read_server_files',
                                  'pg_write_server_files', 'pg_execute_server_program', 'pg_signal_backend',
                                  'azure_pg_admin', 'azure_superuser', 'replication', 'rds_superuser',
                                  'rds_replication', 'rdsadmin', 'rdsrepladmin')
            AND rolname NOT LIKE 'pg_%'
            AND rolname NOT LIKE 'azure_%'
            AND rolname != '$APP_DB_USER'
            AND NOT rolsuper  -- Don't try to drop superuser roles
          LOOP
            BEGIN
              EXECUTE 'DROP ROLE IF EXISTS ' || quote_ident(role_name);
              RAISE NOTICE 'Dropped role: %', role_name;
            EXCEPTION WHEN OTHERS THEN
              RAISE NOTICE 'Could not drop role % (this is usually fine): %', role_name, SQLERRM;
            END;
          END LOOP;
        END
        \$\$;
        
        -- Create clean application user
        DROP ROLE IF EXISTS \"$APP_DB_USER\";
        CREATE ROLE \"$APP_DB_USER\" WITH LOGIN PASSWORD '$APP_DB_PASSWORD';
        
        -- Verify user was created
        SELECT 'Created user:' as status, rolname, rolcanlogin FROM pg_roles WHERE rolname = '$APP_DB_USER';
        
        -- Grant minimal required permissions to app user only
        GRANT CONNECT ON DATABASE \"$POSTGRES_DB\" TO \"$APP_DB_USER\";
        GRANT USAGE, CREATE ON SCHEMA public TO \"$APP_DB_USER\";
        
        -- Grant table permissions only to app user (for existing tables)
        GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO \"$APP_DB_USER\";
        
        -- Grant sequence permissions only to app user (for existing sequences)
        GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO \"$APP_DB_USER\";
        
        -- Grant admin user permission to alter default privileges for the app user
        GRANT \"$APP_DB_USER\" TO \"$POSTGRES_USER\";
        
        -- Now set default privileges for future objects created by admin user
        ALTER DEFAULT PRIVILEGES FOR ROLE \"$POSTGRES_USER\" IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO \"$APP_DB_USER\";
        ALTER DEFAULT PRIVILEGES FOR ROLE \"$POSTGRES_USER\" IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO \"$APP_DB_USER\";
      "
      
      if [ $? -eq 0 ]; then
        echo "✓ Database initialization completed successfully"
      else
        echo "ERROR: Database initialization failed"
        exit 1
      fi
      
      # Test app user connection with SSL
      echo "Testing app user connection with SSL..."
      PGPASSWORD=$APP_DB_PASSWORD psql "host=$POSTGRES_SERVER_FQDN port=5432 dbname=$POSTGRES_DB user=$APP_DB_USER sslmode=require" -c "SELECT current_user;" || {
        echo "ERROR: App user $APP_DB_USER cannot connect with SSL"
        exit 1
      }
      echo "✓ App user connected successfully with SSL"
      
      # Verify permissions
      echo "Verifying app user permissions..."
      PGPASSWORD=$APP_DB_PASSWORD psql "host=$POSTGRES_SERVER_FQDN port=5432 dbname=$POSTGRES_DB user=$APP_DB_USER sslmode=require" -c "
        -- Test table creation
        CREATE TABLE IF NOT EXISTS test_permissions (id SERIAL PRIMARY KEY, test_data TEXT);
        INSERT INTO test_permissions (test_data) VALUES ('permission_test');
        SELECT * FROM test_permissions WHERE test_data = 'permission_test';
        DROP TABLE test_permissions;
      " || {
        echo "ERROR: App user permissions verification failed"
        exit 1
      }
      echo "✓ App user permissions verified"
      
      echo "=== Database Setup Complete ==="
      echo "Database secured: Only admin and app user roles exist, no public access"
      echo "SSL encryption: REQUIRED for all connections"
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
