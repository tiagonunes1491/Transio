#!/bin/bash
set -e

# -------------------------------------------------------------------
# Paths come from env vars defined in the StatefulSet. Use defaults
# only if the variables are absent (local tests, etc.).
# -------------------------------------------------------------------
APP_DB_USER_FILE="${APP_DB_USER_FILE:-/mnt/db-secrets-store/appDbUserKeyVault}"
APP_DB_PASSWORD_FILE="${APP_DB_PASSWORD_FILE:-/mnt/db-secrets-store/appDbPasswordKeyVault}"

echo "Starting database initialization script..."

# ---------- sanity-checks ------------------------------------------------
[[ -f "$APP_DB_USER_FILE"     ]] || { echo "User file not found: $APP_DB_USER_FILE"; exit 1; }
[[ -f "$APP_DB_PASSWORD_FILE" ]] || { echo "Password file not found: $APP_DB_PASSWORD_FILE"; exit 1; }

# ---------- read secrets -------------------------------------------------
APP_DB_USER=$(<"$APP_DB_USER_FILE")
[[ -n "$APP_DB_USER" ]]       || { echo "User file is empty"; exit 1; }

APP_DB_PASSWORD=$(<"$APP_DB_PASSWORD_FILE")
[[ -n "$APP_DB_PASSWORD" ]]   || { echo "Password file is empty"; exit 1; }

echo "Username and password read successfully."

# ---------- postgres DDL -------------------------------------------------
psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" <<-EOSQL
  DO \$\$
  BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '$APP_DB_USER') THEN
      CREATE ROLE "$APP_DB_USER" WITH LOGIN PASSWORD '$APP_DB_PASSWORD';
    ELSE
      ALTER ROLE "$APP_DB_USER" WITH PASSWORD '$APP_DB_PASSWORD';
    END IF;
  END \$\$;

  GRANT CONNECT ON DATABASE "$POSTGRES_DB"   TO "$APP_DB_USER";
  GRANT USAGE  ON SCHEMA  public             TO "$APP_DB_USER";
  ALTER DEFAULT PRIVILEGES IN SCHEMA public
        GRANT SELECT,INSERT,UPDATE,DELETE ON TABLES TO "$APP_DB_USER";

  REVOKE CREATE ON SCHEMA public FROM PUBLIC;      -- nobody else can create
  ALTER  SCHEMA public OWNER TO "$APP_DB_USER";   -- app role becomes owner
  GRANT  USAGE,CREATE ON SCHEMA public TO "$APP_DB_USER";
EOSQL

unset APP_DB_PASSWORD
echo "Database initialization script finished."