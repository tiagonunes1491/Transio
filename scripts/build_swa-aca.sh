#!/usr/bin/env bash
set -euo pipefail

# build_swa-aca.sh - PaaS deployment for Secure Secret Sharer on Azure Container Apps + Static Web Apps
# This script leverages the modular landing zone deployment for PaaS infrastructure
# Usage: ./build_swa-aca.sh [--skip-landing-zone] [--skip-infra] [--skip-containers] [--skip-frontend] [--full-rebuild] [--teardown-only]

# =====================
# Utility Functions
# =====================
log() {
  local level="$1"
  shift
  echo "[$(date '+%Y-%m-%dT%H:%M:%S') $level] $*"
}

# Function to get detailed deployment error information
get_deployment_errors() {
  local deployment_name="$1"
  local resource_group="${2:-}"
  
  log "ERROR" "Deployment failed. Retrieving detailed error information..."
  
  if [[ -n "$resource_group" ]]; then
    # Resource group deployment
    log "INFO" "Getting resource group deployment errors for: $deployment_name in $resource_group"
    az deployment group show --name "$deployment_name" --resource-group "$resource_group" --query 'properties.error' -o json 2>/dev/null || true
    az deployment group operation list --name "$deployment_name" --resource-group "$resource_group" --query '[?properties.provisioningState==`Failed`].{Operation:properties.targetResource.resourceName, Error:properties.statusMessage.error.message}' -o table 2>/dev/null || true
  else
    # Subscription deployment  
    log "INFO" "Getting subscription deployment errors for: $deployment_name"
    az deployment sub show --name "$deployment_name" --query 'properties.error' -o json 2>/dev/null || true
    az deployment sub operation list --name "$deployment_name" --query '[?properties.provisioningState==`Failed`].{Operation:properties.targetResource.resourceName, Error:properties.statusMessage.error.message}' -o table 2>/dev/null || true
  fi
}

# =====================
# Configurable Variables
# =====================
BACKEND_TAG="0.3.0"
SKIP_LANDING_ZONE=false
SKIP_INFRA=false
SKIP_CONTAINERS=false
SKIP_FRONTEND=false
FULL_REBUILD=false
TEARDOWN_ONLY=false

# Parse flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-landing-zone) SKIP_LANDING_ZONE=true; shift ;;
    --skip-infra) SKIP_INFRA=true; shift ;;
    --skip-containers) SKIP_CONTAINERS=true; shift ;;
    --skip-frontend) SKIP_FRONTEND=true; shift ;;
    --full-rebuild) FULL_REBUILD=true; shift ;;
    --teardown-only) TEARDOWN_ONLY=true; shift ;;
    -h|--help)
      echo "Usage: $0 [--skip-landing-zone] [--skip-infra] [--skip-containers] [--skip-frontend] [--full-rebuild] [--teardown-only]"; exit 0 ;;
    *)
      echo "Unknown option: $1"; exit 1 ;;
  esac
  done

# =====================
# Deployment Names & Paths
# =====================
PAAS_DEPLOYMENT_NAME="Secure-Sharer-PaaS"
LOCATION="spaincentral"
PAAS_BICEP_FILE="../infra/swa-aca-platform.bicep"
PAAS_PARAMS_FILE="../infra/swa-aca-platform.dev.bicepparam"
SERVICES=("backend")

# =====================
# Prerequisites
# =====================
log "INFO" "Checking prerequisites..."
command -v az >/dev/null || { log "ERROR" "az CLI not found"; exit 1; }
command -v docker >/dev/null || { log "ERROR" "docker not found"; exit 1; }
command -v swa >/dev/null || { log "ERROR" "swa CLI not found. Install with: npm install -g @azure/static-web-apps-cli"; exit 1; }
log "INFO" "Prerequisites OK"

# =====================
# Teardown Logic
# =====================
if [[ "$TEARDOWN_ONLY" == true ]]; then
  log "INFO" "Teardown-only mode: deleting PaaS resources and landing zone..."
  
  # Use the landing zone teardown functionality
  ./deploy-landing-zone.sh teardown
  log "INFO" "Teardown completed successfully"
  exit 0
fi

if [[ "$FULL_REBUILD" == true ]]; then
  log "INFO" "Full rebuild requested: tearing down PaaS landing zone and resources..."
  
  # Use the landing zone teardown functionality
  ./deploy-landing-zone.sh teardown
  log "INFO" "Teardown completed"
fi

# =====================
# 1. Deploy PaaS Landing Zone
# =====================
if [[ "$SKIP_LANDING_ZONE" == false ]]; then
  log "INFO" "Deploying PaaS landing zone (shared + PaaS spoke)..."
  log "INFO" "This includes user-assigned managed identities and GitHub federation..."
  ./deploy-landing-zone.sh paas
  log "INFO" "PaaS landing zone deployment completed"
else
  log "INFO" "Skipping PaaS landing zone deployment"
fi

# =====================
# 2. Deploy PaaS Infrastructure (Container Apps, Static Web Apps, etc.)
# =====================
if [[ "$SKIP_INFRA" == false ]]; then
  log "INFO" "Deploying PaaS infrastructure (Container Apps Environment, PostgreSQL, etc.)..."
  log "INFO" "This may take 10-15 minutes..."
  if ! az deployment sub create \
    --template-file "$PAAS_BICEP_FILE" \
    --parameters "$PAAS_PARAMS_FILE" \
    --location "$LOCATION" \
    --name "$PAAS_DEPLOYMENT_NAME" \
    --verbose; then
    log "ERROR" "PaaS infrastructure deployment failed"
    get_deployment_errors "$PAAS_DEPLOYMENT_NAME"
    exit 1
  fi
  log "INFO" "PaaS infrastructure deployment completed"
else
  log "INFO" "Skipping PaaS infrastructure deployment"
fi

# =====================
# 3. Retrieve PaaS Infrastructure Outputs
# =====================
log "INFO" "Retrieving outputs from PaaS infrastructure deployment..."
RESOURCE_GROUP=$(az deployment sub show --name "$PAAS_DEPLOYMENT_NAME" --query properties.outputs.resourceGroupName.value -o tsv)
ACA_ENVIRONMENT_ID=$(az deployment sub show --name "$PAAS_DEPLOYMENT_NAME" --query properties.outputs.acaEnvironmentId.value -o tsv)
UAMI_ID=$(az deployment sub show --name "$PAAS_DEPLOYMENT_NAME" --query properties.outputs.uamiId.value -o tsv)
ACR_LOGIN_SERVER=$(az deployment sub show --name "$PAAS_DEPLOYMENT_NAME" --query properties.outputs.acrLoginServer.value -o tsv)
KEY_VAULT_URI=$(az deployment sub show --name "$PAAS_DEPLOYMENT_NAME" --query properties.outputs.keyVaultUri.value -o tsv)
KEY_VAULT_NAME=$(az deployment sub show --name "$PAAS_DEPLOYMENT_NAME" --query properties.outputs.keyVaultName.value -o tsv)
SQL_SERVER_FQDN=$(az deployment sub show --name "$PAAS_DEPLOYMENT_NAME" --query properties.outputs.postgresqlServerFqdn.value -o tsv)
SQL_DATABASE_NAME=$(az deployment sub show --name "$PAAS_DEPLOYMENT_NAME" --query properties.outputs.databaseName.value -o tsv)

log "INFO" "Successfully retrieved PaaS infrastructure outputs:"
log "INFO" "RESOURCE_GROUP=$RESOURCE_GROUP"
log "INFO" "ACA_ENVIRONMENT_ID=$ACA_ENVIRONMENT_ID"
log "INFO" "UAMI_ID=$UAMI_ID"
log "INFO" "ACR_LOGIN_SERVER=$ACR_LOGIN_SERVER"
log "INFO" "KEY_VAULT_URI=$KEY_VAULT_URI"
log "INFO" "KEY_VAULT_NAME=$KEY_VAULT_NAME"
log "INFO" "SQL_SERVER_FQDN=$SQL_SERVER_FQDN"
log "INFO" "SQL_DATABASE_NAME=$SQL_DATABASE_NAME"

# =====================
# 4. Build & Push Container Images
# =====================
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
    docker build -t "$IMAGE" "../$svc" --progress=plain
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

# =====================
# 5. Deploy Azure Container App and Static Web App
# =====================
log "INFO" "Deploying Azure Container App using Bicep template (this may take a few minutes)..."

# Deploy backend container app using Bicep
BACKEND_CONTAINER_IMAGE="secure-secret-sharer-backend:$BACKEND_TAG"
APP_DEPLOYMENT_NAME="backend-app-deployment"

log "INFO" "Deploying backend container app with image: $BACKEND_CONTAINER_IMAGE"

# Use the parameter file and only override the empty parameters with platform deployment outputs
log "INFO" "Using parameter file and overriding empty parameters with platform deployment outputs..."

log "INFO" "Deploying backend container app with Bicep template..."
if ! az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file "../infra/swa-aca-app.bicep" \
  --parameters "../infra/swa-aca-app.dev.bicepparam" \
  --name "$APP_DEPLOYMENT_NAME" \
  --parameters \
    containerImage="$BACKEND_CONTAINER_IMAGE" \
    environmentId="$ACA_ENVIRONMENT_ID" \
    userAssignedIdentityId="$UAMI_ID" \
    acrLoginServer="$ACR_LOGIN_SERVER" \
    keyVaultUri="$KEY_VAULT_URI" \
    postgresqlServerFqdn="$SQL_SERVER_FQDN" \
    databaseName="$SQL_DATABASE_NAME" \
  --verbose; then
  log "ERROR" "Container app deployment failed"
  get_deployment_errors "$APP_DEPLOYMENT_NAME" "$RESOURCE_GROUP"
  exit 1
fi

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

# 6b) Deploy Static Web App with backend linking via Bicep module
if [[ "$SKIP_FRONTEND" == false ]]; then
  log "INFO" "Deploying Static Web App with linked backend (this may take a few minutes)..."
  FRONTEND_DEPLOYMENT_NAME="frontend-deployment"
  if ! az deployment group create \
    --resource-group "$RESOURCE_GROUP" \
    --template-file "../infra/swa-aca-frontend.bicep" \
    --parameters "../infra/swa-aca-frontend.dev.bicepparam" \
    --parameters backendApiResourceId="$BACKEND_RESOURCE_ID" \
    --name "$FRONTEND_DEPLOYMENT_NAME" \
    --verbose; then
    log "ERROR" "Static Web App deployment failed"
    get_deployment_errors "$FRONTEND_DEPLOYMENT_NAME" "$RESOURCE_GROUP"
    exit 1
  fi
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

# =====================
# 6) Summary
# =====================
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

# 6b) Deploy frontend static files to Static Web App production environment
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
    --app-location "../frontend/static" \
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