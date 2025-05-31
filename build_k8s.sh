#!/usr/bin/env bash
set -euo pipefail

# build_dev.sh - Streamlined deployment for Secure Secret Sharer on AKS
# Run inside any Ubuntu distro (e.g., WSL)
# Usage: ./build_dev.sh [--skip-infra] [--skip-containers] [--full-rebuild]

# Default image tags (independent)
BACKEND_TAG="0.3.0"
FRONTEND_TAG="0.3.0"

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
DEPLOYMENT_NAME="secure-secret-sharer-deploy"
LOCATION="spaincentral"
BICEP_FILE="infra/main.bicep"
PARAMS_FILE="infra/main.dev.bicepparam"
SERVICES=("backend" "frontend")

# 1) Prerequisites
echo "[INFO] Checking prerequisites..."
command -v az >/dev/null || { echo "[ERROR] az CLI not found"; exit 1; }
command -v docker >/dev/null || { echo "[ERROR] docker not found"; exit 1; }
command -v kubectl >/dev/null || { echo "[ERROR] kubectl not found"; exit 1; }
command -v helm >/dev/null || { echo "[ERROR] helm not found"; exit 1; }
echo "[INFO] Prerequisites OK"

# 1) Full rebuild teardown
if [[ "$FULL_REBUILD" == true ]]; then
  echo "[INFO] Full rebuild requested: tearing down 'rg-secure-secret-sharer-dev'..."
  echo "[INFO] Deleting resource group (this may take several minutes)..."
  az group delete --name rg-secure-secret-sharer-dev --yes --verbose
  
  echo "[INFO] Purging Key Vault (this may take a few minutes)..."
  az keyvault purge --name kv-securesharer-dev --location spaincentral --verbose
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

echo "[INFO] Successfully retrieved deployment outputs:"
echo "[INFO] AKS_NAME=$AKS_NAME"
echo "[INFO] RESOURCE_GROUP=$RESOURCE_GROUP"
echo "[INFO] ACR_LOGIN_SERVER=$ACR_LOGIN_SERVER"
echo "[INFO] APP_GW_IP=$APP_GW_IP"
echo "[INFO] TENANT_ID=$TENANT_ID"
echo "[INFO] KEY_VAULT_NAME=$KEY_VAULT_NAME"
echo "[INFO] BACKEND_UAMI_CLIENT_ID=$BACKEND_UAMI_CLIENT_ID"
echo "[INFO] DATABASE_UAMI_CLIENT_ID=$DATABASE_UAMI_CLIENT_ID"
echo "[INFO] BACKEND_SERVICE_ACCOUNT_NAME=$BACKEND_SERVICE_ACCOUNT_NAME"
echo "[INFO] DATABASE_SERVICE_ACCOUNT_NAME=$DATABASE_SERVICE_ACCOUNT_NAME"

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

# 5) Connect to AKS
echo "[INFO] Connecting to AKS: $AKS_NAME (this may take a moment)..." 
az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$AKS_NAME" --overwrite-existing --verbose
echo "[INFO] Setting kubectl context..."
kubectl config use-context "$AKS_NAME"
echo "[INFO] Verifying cluster connection..."
kubectl get nodes

echo "[INFO] Successfully connected to AKS cluster"

# 6) Deploy Helm chart with enhanced monitoring
echo "[INFO] Deploying Helm chart (this may take a few minutes)..."

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


echo "[INFO] Starting Helm deployment..."
helm upgrade --install secret-sharer k8s/secret-sharer-app \
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