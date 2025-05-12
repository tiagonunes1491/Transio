#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

# Variables
# POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB are automatically available from container env vars
APP_DB_USER_ENV_VAR="APP_DB_USER" # Env var for the app username (still needed)
# Path where the CSI driver mounts the app password file, based on objectAlias in SPC
APP_DB_PASSWORD_FILE="/mnt/db-secrets-store/appDbPasswordKeyVault"

echo "Starting database initialization script..."

# Get App Username from Env Var (sourced from values.yaml in StatefulSet)
APP_DB_USER="${!APP_DB_USER_ENV_VAR}"

# Check if required inputs are available
if [ -z "$APP_DB_USER" ]; then
  echo "Error: Required environment variable APP_DB_USER is not set."
  exit 1
fi
if [ ! -f "$APP_DB_PASSWORD_FILE" ]; then
  echo "Error: Application password file '$APP_DB_PASSWORD_FILE' not found. Check SecretProviderClass and volume mount."
  exit 1
fi

# Read the password from the mounted file
APP_DB_PASSWORD=$(cat "$APP_DB_PASSWORD_FILE")
if [ -z "$APP_DB_PASSWORD" ]; then
    echo "Error: Application password file '$APP_DB_PASSWORD_FILE' is empty."
    exit 1
fi

echo "Read application username and password successfully."

# Use psql to execute SQL commands
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Create the application user if it doesn't exist
    DO
    \$do\$
    BEGIN
       IF NOT EXISTS (
          SELECT FROM pg_catalog.pg_roles
          WHERE  rolname = '$APP_DB_USER') THEN

          -- Use password read from file
          CREATE ROLE "$APP_DB_USER" WITH LOGIN PASSWORD '$APP_DB_PASSWORD';
          RAISE NOTICE 'Role "$APP_DB_USER" created.';
       ELSE
          RAISE NOTICE 'Role "$APP_DB_USER" already exists. Skipping creation.';
          -- Optionally update password if needed:
          -- ALTER ROLE "$APP_DB_USER" WITH PASSWORD '$APP_DB_PASSWORD';
       END IF;
    END
    \$do\$;

    -- Grant connect permissions
    GRANT CONNECT ON DATABASE "$POSTGRES_DB" TO "$APP_DB_USER";
    RAISE NOTICE 'CONNECT permission granted to "$APP_DB_USER" on database "$POSTGRES_DB".';

    -- Grant schema usage
    GRANT USAGE ON SCHEMA public TO "$APP_DB_USER";
    RAISE NOTICE 'USAGE permission granted to "$APP_DB_USER" on schema public.';

    -- Grant default privileges for future tables/sequences
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO "$APP_DB_USER";
    RAISE NOTICE 'Default table permissions granted to "$APP_DB_USER" in schema public.';
    -- ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO "$APP_DB_USER";
    -- RAISE NOTICE 'Default sequence permissions granted to "$APP_DB_USER" in schema public.';

    -- Grant permissions on the specific 'secrets' table if it exists now
    DO \$\$
    BEGIN
       IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'secrets') THEN
          GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.secrets TO "$APP_DB_USER";
          RAISE NOTICE 'Permissions granted to "$APP_DB_USER" on existing table public.secrets.';
       END IF;
    END
    \$\$;

    SELECT 'Database initialization script completed successfully.' AS status;
EOSQL

# --- SECURITY: Clear the password variable ---
unset APP_DB_PASSWORD

echo "Database initialization script finished."