#!/usr/bin/env bash
set -euo pipefail

# build_swa-aca.sh - Streamlined deployment for Secure Secret Sharer on Azure Container Apps
# Run inside any Ubuntu distro (e.g., WSL)
# Usage: ./build_swa-aca.sh [--skip-infra] [--skip-containers] [--skip-frontend] [--full-rebuild] [--teardown-only]

# Function to print timestamped messages
log() {
  local level="$1"
  shift
  echo "[$(date '+%Y-%m-%dT%H:%M:%S') $level] $*"
}

# Default image tags (independent)
BACKEND_TAG="0.3.0"

SKIP_INFRA=false
SKIP_CONTAINERS=false
SKIP_FRONTEND=false
FULL_REBUILD=false
TEARDOWN_ONLY=false

# Parse flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-infra) SKIP_INFRA=true; shift ;;  
    --skip-containers) SKIP_CONTAINERS=true; shift ;;  
    --skip-frontend) SKIP_FRONTEND=true; shift ;;
    --full-rebuild) FULL_REBUILD=true; shift ;;
    --teardown-only) TEARDOWN_ONLY=true; shift ;;
    -h|--help) 
      echo "Usage: $0 [--skip-infra] [--skip-containers] [--skip-frontend] [--full-rebuild] [--teardown-only]"; exit 0 ;;  
    *) 
      echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Configuration
DEPLOYMENT_NAME="Secure-Sharer-SWA-Dev"
LOCATION="spaincentral"
BICEP_FILE="infra/swa-aca-platform.bicep"
PARAMS_FILE="infra/swa-aca-platform.dev.bicepparam"
SERVICES=("backend")

# 1) Prerequisites
log "INFO" "Checking prerequisites..."
command -v az >/dev/null || { log "ERROR" "az CLI not found"; exit 1; }
command -v docker >/dev/null || { log "ERROR" "docker not found"; exit 1; }
command -v swa >/dev/null || { log "ERROR" "swa CLI not found. Install with: npm install -g @azure/static-web-apps-cli"; exit 1; }
log "INFO" "Prerequisites OK"

# Teardown-only mode: delete resources and exit
if [[ "$TEARDOWN_ONLY" == true ]]; then
  log "INFO" "Teardown-only mode: deleting 'rg-secure-sharer-swa-dev' and purging Key Vault..."
  log "INFO" "Deleting resource group (this may take several minutes)..."
  az group delete --name rg-secure-sharer-swa-dev --yes --verbose
  
  log "INFO" "Purging Key Vault (this may take a few minutes)..."
  az keyvault purge --name kv-securesharer-swa-dev --verbose
  log "INFO" "Teardown completed successfully"
  log "INFO" "Exiting - no deployment performed"
  exit 0
fi

# 1) Full rebuild teardown
if [[ "$FULL_REBUILD" == true ]]; then
  log "INFO" "Full rebuild requested: tearing down 'rg-secure-sharer-swa-dev'..."
  log "INFO" "Deleting resource group (this may take several minutes)..."
  az group delete --name rg-secure-sharer-swa-dev --yes --verbose
  
  log "INFO" "Purging Key Vault (this may take a few minutes)..."
  az keyvault purge --name kv-securesharer-swa-dev --verbose
  log "INFO" "Teardown completed"
fi

# 2) Deploy infrastructure
if [[ "$SKIP_INFRA" == false ]]; then
  log "INFO" "Deploying Bicep infrastructure (this may take 10-15 minutes)..."
  log "INFO" "You will see detailed deployment progress below..."
  az deployment sub create --template-file "$BICEP_FILE" --parameters "$PARAMS_FILE" --location "$LOCATION" \
    --name "$DEPLOYMENT_NAME" --verbose
  log "INFO" "Infrastructure deployment completed"
else
  log "INFO" "Skipping infrastructure deployment"
fi

# 3) Retrieve outputs from Bicep deployment
log "INFO" "Retrieving deployment outputs from Azure..."
log "INFO" "This may take a moment while querying the deployment state..."

# Core infrastructure outputs
ACA_ENVIRONMENT_ID=$(az deployment sub show --name "$DEPLOYMENT_NAME" --query properties.outputs.acaEnvironmentId.value -o tsv)
RESOURCE_GROUP="rg-secure-sharer-swa-dev"
ACR_LOGIN_SERVER=$(az deployment sub show --name "$DEPLOYMENT_NAME" --query properties.outputs.acrLoginServer.value -o tsv)
KEY_VAULT_URI=$(az deployment sub show --name "$DEPLOYMENT_NAME" --query properties.outputs.keyVaultUri.value -o tsv)
SQL_SERVER_FQDN=$(az deployment sub show --name "$DEPLOYMENT_NAME" --query properties.outputs.sqlServerFqdn.value -o tsv)
SQL_DATABASE_NAME=$(az deployment sub show --name "$DEPLOYMENT_NAME" --query properties.outputs.sqlDatabaseName.value -o tsv)
UAMI_ID=$(az deployment sub show --name "$DEPLOYMENT_NAME" --query properties.outputs.uamiId.value -o tsv)

# Extract key vault name from URI
KEY_VAULT_NAME=$(echo "$KEY_VAULT_URI" | sed 's|https://||' | sed 's|\.vault\.azure\.net/||')

log "INFO" "Successfully retrieved deployment outputs:"
log "INFO" "ACA_ENVIRONMENT_ID=$ACA_ENVIRONMENT_ID"
log "INFO" "RESOURCE_GROUP=$RESOURCE_GROUP"
log "INFO" "ACR_LOGIN_SERVER=$ACR_LOGIN_SERVER"
log "INFO" "KEY_VAULT_NAME=$KEY_VAULT_NAME"
log "INFO" "KEY_VAULT_URI=$KEY_VAULT_URI"
log "INFO" "SQL_SERVER_FQDN=$SQL_SERVER_FQDN"
log "INFO" "SQL_DATABASE_NAME=$SQL_DATABASE_NAME"
log "INFO" "UAMI_ID=$UAMI_ID"

# 4) Build & push container images
if [[ "$SKIP_CONTAINERS" == false ]]; then
  log "INFO" "Logging into Azure Container Registry..."
  ACR_NAME="${ACR_LOGIN_SERVER%%.*}"
  az acr login --name "$ACR_NAME" --verbose
  log "INFO" "Building and pushing container images..."
  IMAGES=()
  for svc in "${SERVICES[@]}"; do
    TAG_VAR="${svc^^}_TAG"
    TAG_VALUE="${!TAG_VAR:-latest}"
    IMAGE="$ACR_LOGIN_SERVER/secure-secret-sharer-$svc:$TAG_VALUE"
    log "INFO" "Building $svc image ($TAG_VALUE) - this may take several minutes..."
    docker build -t "$IMAGE" "./$svc" --progress=plain
    log "INFO" "Pushing $svc image to ACR..."
    docker push "$IMAGE"
    IMAGES+=("$svc:$IMAGE")
    log "INFO" "Completed $svc image: $IMAGE"
  done
else
  log "INFO" "Skipping container build & push"
  # Build image references for existing images when skipping container build
  IMAGES=()
  for svc in "${SERVICES[@]}"; do
    TAG_VAR="${svc^^}_TAG"
    TAG_VALUE="${!TAG_VAR:-latest}"
    IMAGE="$ACR_LOGIN_SERVER/secure-secret-sharer-$svc:$TAG_VALUE"
    IMAGES+=("$svc:$IMAGE")
  done
fi

# 5) Deploy Azure Container App using Bicep
log "INFO" "Deploying Azure Container App using Bicep template (this may take a few minutes)..."

# Deploy backend container app using Bicep
BACKEND_CONTAINER_IMAGE="secure-secret-sharer-backend:$BACKEND_TAG"
APP_DEPLOYMENT_NAME="backend-app-deployment"

log "INFO" "Deploying backend container app with image: $BACKEND_CONTAINER_IMAGE"

# Use the parameter file and only override the empty parameters with platform deployment outputs
log "INFO" "Using parameter file and overriding empty parameters with platform deployment outputs..."

log "INFO" "Deploying backend container app with Bicep template..."
az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file "infra/swa-aca-app.bicep" \
  --parameters "infra/swa-aca-app.dev.bicepparam" \
  --name "$APP_DEPLOYMENT_NAME" \
  --parameters \
    containerImage="$BACKEND_CONTAINER_IMAGE" \
    environmentId="$ACA_ENVIRONMENT_ID" \
    userAssignedIdentityId="$UAMI_ID" \
    acrLoginServer="$ACR_LOGIN_SERVER" \
    keyVaultUri="$KEY_VAULT_URI" \
    postgresqlServerFqdn="$SQL_SERVER_FQDN" \
    databaseName="$SQL_DATABASE_NAME" \
  --verbose

# Get the actual app name from the deployment output and then get backend FQDN
log "INFO" "Retrieving container app details..."
APP_NAME=$(az deployment group show --name "$APP_DEPLOYMENT_NAME" --resource-group "$RESOURCE_GROUP" --query properties.parameters.appName.value -o tsv)

# Fallback to default app name if deployment query fails
if [[ -z "$APP_NAME" || "$APP_NAME" == "null" ]]; then
  log "WARNING" "Could not retrieve app name from deployment. Using default name."
  APP_NAME="secure-secret-sharer-aca-dev"
fi

log "INFO" "Container app name: $APP_NAME"

# Verify the container app exists before trying to get FQDN
if ! az containerapp show --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" > /dev/null 2>&1; then
  log "ERROR" "Container app '$APP_NAME' not found in resource group '$RESOURCE_GROUP'"
  log "INFO" "Available container apps:"
  az containerapp list --resource-group "$RESOURCE_GROUP" --query '[].name' -o tsv
  exit 1
fi

BACKEND_FQDN=$(az containerapp show --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" --query properties.configuration.ingress.fqdn -o tsv)

# Get the backend resource ID for linking
BACKEND_RESOURCE_ID=$(az containerapp show --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" --query id -o tsv)

log "INFO" "Backend FQDN: $BACKEND_FQDN"
log "INFO" "Backend Resource ID: $BACKEND_RESOURCE_ID"
# ensure BACKEND_URL is set for summary
export BACKEND_URL="$BACKEND_FQDN"

# 6) Deploy Static Web App with backend linking via Bicep module
if [[ "$SKIP_FRONTEND" == false ]]; then
  log "INFO" "Deploying Static Web App with linked backend (this may take a few minutes)..."
  FRONTEND_DEPLOYMENT_NAME="frontend-deployment"
  az deployment group create \
    --resource-group "$RESOURCE_GROUP" \
    --template-file "infra/swa-aca-frontend.bicep" \
    --parameters "infra/swa-aca-frontend.bicepparam" \
    --parameters backendApiResourceId="$BACKEND_RESOURCE_ID" \
    --name "$FRONTEND_DEPLOYMENT_NAME" \
    --verbose
  # retrieve outputs using --query and tsv
  STATIC_WEB_APP_URL=$(az deployment group show \
    --name "$FRONTEND_DEPLOYMENT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query properties.outputs.staticWebAppUrl.value -o tsv)
  STATIC_WEB_APP_NAME=$(az deployment group show \
    --name "$FRONTEND_DEPLOYMENT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query properties.outputs.staticWebAppName.value -o tsv)
  export STATIC_WEB_APP_URL STATIC_WEB_APP_NAME
else
  log "INFO" "Skipping Static Web App deployment"
  STATIC_WEB_APP_URL="(skipped)"
  STATIC_WEB_APP_NAME="(skipped)"
fi

echo ""
echo "=============================================="
echo "DEPLOYMENT SUMMARY"
echo "=============================================="
echo "Frontend URL: $STATIC_WEB_APP_URL"
echo "Backend URL: $BACKEND_URL"
echo "Static Web App Name: $STATIC_WEB_APP_NAME"
echo "Backend Resource ID: $BACKEND_RESOURCE_ID"
echo ""
echo "Infrastructure Details:"
echo "ACA Environment: $ACA_ENVIRONMENT_ID"
echo "Resource Group: $RESOURCE_GROUP"
echo "Key Vault: $KEY_VAULT_NAME"
echo "Container Registry: $ACR_LOGIN_SERVER"
echo "PostgreSQL Server: $SQL_SERVER_FQDN"
echo "Database Name: $SQL_DATABASE_NAME"
echo "Managed Identity: $UAMI_ID"
echo ""
echo "🎉 Deployment Complete!"
echo "✅ Backend is linked to Static Web App"
echo "✅ API requests to /api/* will route to your Container App"
echo "=============================================="

# 7) Deploy frontend static files to Static Web App production environment
if [[ "$SKIP_FRONTEND" == false ]]; then
  echo ""
  log "INFO" "Deploying frontend static files to Static Web App production environment..."
  
  # Retrieve the deployment token for the Static Web App
  log "INFO" "Retrieving deployment token for Static Web App: $STATIC_WEB_APP_NAME"
  DEPLOYMENT_TOKEN=$(az staticwebapp secrets list \
    --name "$STATIC_WEB_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query properties.apiKey -o tsv)
  
  if [[ -z "$DEPLOYMENT_TOKEN" || "$DEPLOYMENT_TOKEN" == "null" ]]; then
    log "ERROR" "Failed to retrieve deployment token for Static Web App"
    exit 1
  fi
  
  log "INFO" "Deployment token retrieved successfully"
  log "INFO" "Deploying static files from ./frontend/static to production environment..."
  
  # Deploy static files using SWA CLI
  swa deploy \
    --app-location "./frontend/static" \
    --deployment-token "$DEPLOYMENT_TOKEN" \
    --env "production"
  
  log "INFO" "✅ Static files deployed successfully to production environment"
else
  log "INFO" "Skipping frontend static files deployment (frontend deployment was skipped)"
fi

echo ""
echo "=============================================="
echo "🚀 FINAL DEPLOYMENT STATUS"
echo "=============================================="
echo "✅ Infrastructure: Deployed"
echo "✅ Backend Container App: Deployed and running"
if [[ "$SKIP_FRONTEND" == false ]]; then
  echo "✅ Static Web App: Deployed with backend linking"
  echo "✅ Frontend Static Files: Deployed to production"
else
  echo "⏭️  Static Web App: Skipped"
  echo "⏭️  Frontend Static Files: Skipped"
fi
echo ""
echo "🌐 Your application is ready at: $STATIC_WEB_APP_URL"
echo "=============================================="