#!/usr/bin/env bash
set -euo pipefail

# build_swa-aca.sh - Streamlined deployment for Secure Secret Sharer on Azure Container Apps
# Run inside any Ubuntu distro (e.g., WSL)
# Usage: ./build_swa-aca.sh [--skip-infra] [--skip-containers] [--full-rebuild]

# Default image tags (independent)
BACKEND_TAG="0.3.0"

SKIP_INFRA=false
SKIP_CONTAINERS=false
FULL_REBUILD=false

# Parse flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-infra) SKIP_INFRA=true; shift ;;  
    --skip-containers) SKIP_CONTAINERS=true; shift ;;  
    --full-rebuild) FULL_REBUILD=true; shift ;;
    -h|--help) 
      echo "Usage: $0 [--skip-infra] [--skip-containers] [--full-rebuild]"; exit 0 ;;  
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
echo "[INFO] Checking prerequisites..."
command -v az >/dev/null || { echo "[ERROR] az CLI not found"; exit 1; }
command -v docker >/dev/null || { echo "[ERROR] docker not found"; exit 1; }
echo "[INFO] Prerequisites OK"

# 1) Full rebuild teardown
if [[ "$FULL_REBUILD" == true ]]; then
  echo "[INFO] Full rebuild requested: tearing down 'rg-secure-sharer-swa-dev'..."
  echo "[INFO] Deleting resource group (this may take several minutes)..."
  az group delete --name rg-secure-sharer-swa-dev --yes --verbose
  
  echo "[INFO] Purging Key Vault (this may take a few minutes)..."
  az keyvault purge --name kv-securesharer-swa-dev --verbose
  echo "[INFO] Teardown completed"
fi

# 2) Deploy infrastructure
if [[ "$SKIP_INFRA" == false ]]; then
  echo "[INFO] Deploying Bicep infrastructure (this may take 10-15 minutes)..."
  echo "[INFO] You will see detailed deployment progress below..."
  az deployment sub create --template-file "$BICEP_FILE" --parameters "$PARAMS_FILE" --location "$LOCATION" \
    --name "$DEPLOYMENT_NAME" --verbose
  echo "[INFO] Infrastructure deployment completed"
else
  echo "[INFO] Skipping infrastructure deployment"
fi

# 3) Retrieve outputs from Bicep deployment
echo "[INFO] Retrieving deployment outputs from Azure..."
echo "[INFO] This may take a moment while querying the deployment state..."

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

echo "[INFO] Successfully retrieved deployment outputs:"
echo "[INFO] ACA_ENVIRONMENT_ID=$ACA_ENVIRONMENT_ID"
echo "[INFO] RESOURCE_GROUP=$RESOURCE_GROUP"
echo "[INFO] ACR_LOGIN_SERVER=$ACR_LOGIN_SERVER"
echo "[INFO] KEY_VAULT_NAME=$KEY_VAULT_NAME"
echo "[INFO] KEY_VAULT_URI=$KEY_VAULT_URI"
echo "[INFO] SQL_SERVER_FQDN=$SQL_SERVER_FQDN"
echo "[INFO] SQL_DATABASE_NAME=$SQL_DATABASE_NAME"
echo "[INFO] UAMI_ID=$UAMI_ID"

# 4) Build & push container images
if [[ "$SKIP_CONTAINERS" == false ]]; then
  echo "[INFO] Logging into Azure Container Registry..."
  ACR_NAME="${ACR_LOGIN_SERVER%%.*}"
  az acr login --name "$ACR_NAME" --verbose
  echo "[INFO] Building and pushing container images..."
  IMAGES=()
  for svc in "${SERVICES[@]}"; do
    TAG_VAR="${svc^^}_TAG"
    TAG_VALUE="${!TAG_VAR:-latest}"
    IMAGE="$ACR_LOGIN_SERVER/secure-secret-sharer-$svc:$TAG_VALUE"
    echo "[INFO] Building $svc image ($TAG_VALUE) - this may take several minutes..."
    docker build -t "$IMAGE" "./$svc" --progress=plain
    echo "[INFO] Pushing $svc image to ACR..."
    docker push "$IMAGE"
    IMAGES+=("$svc:$IMAGE")
    echo "[INFO] Completed $svc image: $IMAGE"
  done
else
  echo "[INFO] Skipping container build & push"
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
echo "[INFO] Deploying Azure Container App using Bicep template (this may take a few minutes)..."

# Deploy backend container app using Bicep
BACKEND_CONTAINER_IMAGE="secure-secret-sharer-backend:$BACKEND_TAG"
APP_DEPLOYMENT_NAME="backend-app-deployment"

echo "[INFO] Deploying backend container app with image: $BACKEND_CONTAINER_IMAGE"

# Use the parameter file and only override the empty parameters with platform deployment outputs
echo "[INFO] Using parameter file and overriding empty parameters with platform deployment outputs..."

echo "[INFO] Deploying backend container app with Bicep template..."
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
    SqlDatabaseName="$SQL_DATABASE_NAME" \
  --verbose

# Get the actual app name from the deployment output and then get backend FQDN
echo "[INFO] Retrieving container app details..."
APP_NAME=$(az deployment group show --name "$APP_DEPLOYMENT_NAME" --resource-group "$RESOURCE_GROUP" --query properties.parameters.appName.value -o tsv)
echo "[INFO] Container app name: $APP_NAME"

BACKEND_FQDN=$(az containerapp show --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" --query properties.configuration.ingress.fqdn -o tsv)

echo ""
echo "=============================================="
echo "DEPLOYMENT SUMMARY"
echo "=============================================="
echo "Backend URL: https://$BACKEND_FQDN"
echo "ACA Environment: $ACA_ENVIRONMENT_ID"
echo "Resource Group: $RESOURCE_GROUP"
echo "Key Vault: $KEY_VAULT_NAME"
echo "Container Registry: $ACR_LOGIN_SERVER"
echo "PostgreSQL Server: $SQL_SERVER_FQDN"
echo "Database Name: $SQL_DATABASE_NAME"
echo "Managed Identity: $UAMI_ID"
echo "=============================================="