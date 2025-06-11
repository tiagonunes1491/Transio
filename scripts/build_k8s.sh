#!/usr/bin/env bash
set -euo pipefail

# build_dev.sh - Streamlined deployment for Secure Secret Sharer on AKS
# Run inside any Ubuntu distro (e.g., WSL)
# Usage: ./build_dev.sh [--skip-infra] [--skip-containers] [--full-rebuild] [--teardown-only]

# Function to print timestamped messages
log() {
  local level="$1"
  shift
  echo "[$(date '+%Y-%m-%dT%H:%M:%S') $level] $*"
}

# Default image tags (independent)
BACKEND_TAG="0.3.0"
FRONTEND_TAG="0.3.0"

SKIP_INFRA=false
SKIP_CONTAINERS=false
FULL_REBUILD=false
TEARDOWN_ONLY=false

# Parse flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-infra) SKIP_INFRA=true; shift ;;  
    --skip-containers) SKIP_CONTAINERS=true; shift ;;  
    --full-rebuild) FULL_REBUILD=true; shift ;;
    --teardown-only) TEARDOWN_ONLY=true; shift ;;
    -h|--help) 
      echo "Usage: $0 [--skip-infra] [--skip-containers] [--full-rebuild] [--teardown-only]"; exit 0 ;;  
    *) 
      echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Configuration
DEPLOYMENT_NAME="secure-secret-sharer-deploy"
LOCATION="spaincentral"
BICEP_FILE="../infra/k8s-main.bicep"
PARAMS_FILE="../infra/k8s-main.bicep.dev.bicepparam"
SERVICES=("backend" "frontend")

# 1) Prerequisites
log "INFO" "Checking prerequisites..."
command -v az >/dev/null || { log "ERROR" "az CLI not found"; exit 1; }
command -v docker >/dev/null || { log "ERROR" "docker not found"; exit 1; }
command -v kubectl >/dev/null || { log "ERROR" "kubectl not found"; exit 1; }
command -v helm >/dev/null || { log "ERROR" "helm not found"; exit 1; }
log "INFO" "Prerequisites OK"

# Teardown-only mode: delete resources and exit
if [[ "$TEARDOWN_ONLY" == true ]]; then
  log "INFO" "Teardown-only mode: deleting 'rg-secure-secret-sharer-dev' and purging Key Vault..."
  
  # Delete Helm deployment first (if exists)
  log "INFO" "Checking for existing Helm deployment..."
  if command -v helm >/dev/null && helm list --namespace default 2>/dev/null | grep -q "secret-sharer"; then
    log "INFO" "Uninstalling Helm chart 'secret-sharer'..."
    helm uninstall secret-sharer --namespace default
    log "INFO" "Helm chart uninstalled"
  else
    log "INFO" "No Helm deployment found or helm not available, skipping..."
  fi
  
  log "INFO" "Deleting resource group (this may take several minutes)..."
  az group delete --name rg-secure-secret-sharer-dev --yes --verbose
  
  log "INFO" "Purging Key Vault (this may take a few minutes)..."
  az keyvault purge --name kv-securesharer-dev --location spaincentral --verbose
  
  # Clean up local kubectl context (optional)
  log "INFO" "Cleaning up local kubectl context..."
  AKS_NAME="aks-secure-secret-sharer-dev"
  if command -v kubectl >/dev/null && kubectl config get-contexts 2>/dev/null | grep -q "$AKS_NAME"; then
    kubectl config delete-context "$AKS_NAME" 2>/dev/null || true
    log "INFO" "Kubectl context for '$AKS_NAME' removed"
  else
    log "INFO" "No kubectl context found for '$AKS_NAME' or kubectl not available, skipping..."
  fi
  
  log "INFO" "Teardown completed successfully"
  log "INFO" "Exiting - no deployment performed"
  exit 0
fi

# 1) Full rebuild teardown
if [[ "$FULL_REBUILD" == true ]]; then
  log "INFO" "Full rebuild requested: tearing down 'rg-secure-secret-sharer-dev'..."
  log "INFO" "Deleting resource group (this may take several minutes)..."
  az group delete --name rg-secure-secret-sharer-dev --yes --verbose
  
  log "INFO" "Purging Key Vault (this may take a few minutes)..."
  az keyvault purge --name kv-securesharer-dev --location spaincentral --verbose
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
AKS_NAME=$(az deployment sub show --name "$DEPLOYMENT_NAME" --query properties.outputs.aksName.value -o tsv)
RESOURCE_GROUP=$(az deployment sub show --name "$DEPLOYMENT_NAME" --query properties.outputs.resourceGroupName.value -o tsv)
ACR_LOGIN_SERVER=$(az deployment sub show --name "$DEPLOYMENT_NAME" --query properties.outputs.acrLoginServer.value -o tsv)
APP_GW_IP=$(az deployment sub show --name "$DEPLOYMENT_NAME" --query properties.outputs.appGwPublicIp.value -o tsv)

# Azure configuration outputs for Helm
TENANT_ID=$(az deployment sub show --name "$DEPLOYMENT_NAME" --query properties.outputs.tenantId.value -o tsv)
KEY_VAULT_NAME=$(az deployment sub show --name "$DEPLOYMENT_NAME" --query properties.outputs.keyvaultName.value -o tsv)
BACKEND_UAMI_CLIENT_ID=$(az deployment sub show --name "$DEPLOYMENT_NAME" --query properties.outputs.backendUamiClientId.value -o tsv)
DATABASE_UAMI_CLIENT_ID=$(az deployment sub show --name "$DEPLOYMENT_NAME" --query properties.outputs.dbInitUamiClientId.value -o tsv)
BACKEND_SERVICE_ACCOUNT_NAME=$(az deployment sub show --name "$DEPLOYMENT_NAME" --query properties.outputs.backendK8sServiceAccountName.value -o tsv)
DATABASE_SERVICE_ACCOUNT_NAME=$(az deployment sub show --name "$DEPLOYMENT_NAME" --query properties.outputs.databaseInitK8sServiceAccountName.value -o tsv)

log "INFO" "Successfully retrieved deployment outputs:"
log "INFO" "AKS_NAME=$AKS_NAME"
log "INFO" "RESOURCE_GROUP=$RESOURCE_GROUP"
log "INFO" "ACR_LOGIN_SERVER=$ACR_LOGIN_SERVER"
log "INFO" "APP_GW_IP=$APP_GW_IP"
log "INFO" "TENANT_ID=$TENANT_ID"
log "INFO" "KEY_VAULT_NAME=$KEY_VAULT_NAME"
log "INFO" "BACKEND_UAMI_CLIENT_ID=$BACKEND_UAMI_CLIENT_ID"
log "INFO" "DATABASE_UAMI_CLIENT_ID=$DATABASE_UAMI_CLIENT_ID"
log "INFO" "BACKEND_SERVICE_ACCOUNT_NAME=$BACKEND_SERVICE_ACCOUNT_NAME"
log "INFO" "DATABASE_SERVICE_ACCOUNT_NAME=$DATABASE_SERVICE_ACCOUNT_NAME"

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

# 5) Connect to AKS
log "INFO" "Connecting to AKS: $AKS_NAME (this may take a moment)..." 
az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$AKS_NAME" --overwrite-existing --verbose
log "INFO" "Setting kubectl context..."
kubectl config use-context "$AKS_NAME"
log "INFO" "Verifying cluster connection..."
kubectl get nodes

log "INFO" "Successfully connected to AKS cluster"

# 6) Deploy Helm chart with enhanced monitoring
log "INFO" "Deploying Helm chart (this may take a few minutes)..."

# Parse image references from IMAGES array
BACKEND_REPO=""
BACKEND_TAG=""
FRONTEND_REPO=""
FRONTEND_TAG=""

for image_entry in "${IMAGES[@]}"; do
  svc="${image_entry%%:*}"
  image="${image_entry#*:}"
  repo="${image%:*}"
  tag="${image##*:}"
  
  if [[ "$svc" == "backend" ]]; then
    BACKEND_REPO="$repo"
    BACKEND_TAG="$tag"
  elif [[ "$svc" == "frontend" ]]; then
    FRONTEND_REPO="$repo"
    FRONTEND_TAG="$tag"
  fi
done


log "INFO" "Starting Helm deployment..."
helm upgrade --install secret-sharer ../k8s/secret-sharer-app \
  --namespace default --create-namespace \
  --set backend.keyVault.name="$KEY_VAULT_NAME" \
  --set backend.keyVault.tenantId="$TENANT_ID" \
  --set backend.keyVault.userAssignedIdentityClientID="$BACKEND_UAMI_CLIENT_ID" \
  --set backend.serviceAccount.name="$BACKEND_SERVICE_ACCOUNT_NAME" \
  --set database.serviceAccount.azureClientId="$DATABASE_UAMI_CLIENT_ID" \
  --set database.serviceAccount.name="$DATABASE_SERVICE_ACCOUNT_NAME" \
  --set backend.image.tag="$BACKEND_TAG" \
  --set frontend.image.tag="$FRONTEND_TAG" \
  --set acrLoginServer="$ACR_LOGIN_SERVER" \
  --timeout=15m \
  --wait

# Display hosts file entry for manual addition
HOSTNAME="secretsharer.local"

echo ""
echo "=============================================="
echo "MANUAL HOSTS FILE UPDATE REQUIRED"
echo "=============================================="
echo ""
echo "Copy and paste this command in PowerShell (Run as Administrator) to ADD/UPDATE hosts entry:"
echo ""
echo "(Get-Content C:\\Windows\\System32\\drivers\\etc\\hosts | Where-Object {\$_ -notmatch '$HOSTNAME'}) + '$APP_GW_IP $HOSTNAME' | Set-Content C:\\Windows\\System32\\drivers\\etc\\hosts"
echo ""
echo "Copy and paste this command in PowerShell (Run as Administrator) to REMOVE hosts entry:"
echo ""
echo "Get-Content C:\\Windows\\System32\\drivers\\etc\\hosts | Where-Object {\$_ -notmatch '$HOSTNAME'} | Set-Content C:\\Windows\\System32\\drivers\\etc\\hosts"
echo ""
echo "=============================================="

echo ""
echo "=============================================="
echo "DEPLOYMENT SUMMARY"
echo "=============================================="
echo "Application URL: http://$HOSTNAME"
echo "AKS Cluster: $AKS_NAME"
echo "Resource Group: $RESOURCE_GROUP"
echo "Key Vault: $KEY_VAULT_NAME"
echo "Container Registry: $ACR_LOGIN_SERVER"
echo "Tenant ID: $TENANT_ID"
echo "Backend Identity: $BACKEND_UAMI_CLIENT_ID"
echo "Database Identity: $DATABASE_UAMI_CLIENT_ID"
echo "=============================================="