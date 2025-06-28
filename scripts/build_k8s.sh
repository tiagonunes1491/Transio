#!/usr/bin/env bash
set -euo pipefail

# build_k8s.sh - Streamlined deployment for Secure Secret Sharer on AKS
# This script leverages the modular landing zone deployment architecture:
# 1. Deploys landing zone infrastructure (0-lz) with aks-dev.bicepparam
# 2. Deploys AKS platform infrastructure (aks10-platform) 
# 3. Builds and pushes container images to ACR
# 4. Deploys Helm chart to AKS cluster
# Run inside any Ubuntu distro (e.g., WSL)
# Usage: ./build_k8s.sh [OPTIONS]
# 
# OPTIONS:
#   --skip-landing-zone    Skip landing zone deployment (use existing)
#   --skip-infra          Skip AKS platform infrastructure deployment (use existing)
#   --skip-containers     Skip container build and push (use existing images)
#   --full-rebuild        Perform complete teardown (stacks, RG, KV purge) then deploy fresh
#   --teardown-only       Perform complete teardown and exit (no deployment)
#   -h, --help           Show this help message
#
# TEARDOWN PROCESS:
#   1. Uninstall Helm deployments
#   2. Delete AKS platform stack
#   3. Delete landing zone stack  
#   4. Delete resource group completely
#   5. Purge Key Vault (permanent deletion)
#   6. Clean up local kubectl contexts

# Function to print timestamped messages
log() {
  local level="$1"
  shift
  echo "[$(date '+%Y-%m-%dT%H:%M:%S') $level] $*"
}

# Default image tags (independent)
BACKEND_TAG="0.3.0"
FRONTEND_TAG="0.3.0"

SKIP_LANDING_ZONE=false
SKIP_INFRA=false
SKIP_CONTAINERS=false
FULL_REBUILD=false
TEARDOWN_ONLY=false

# Parse flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-landing-zone) SKIP_LANDING_ZONE=true; shift ;;
    --skip-infra) SKIP_INFRA=true; shift ;;  
    --skip-containers) SKIP_CONTAINERS=true; shift ;;  
    --full-rebuild) FULL_REBUILD=true; shift ;;
    --teardown-only) TEARDOWN_ONLY=true; shift ;;
    -h|--help) 
      echo "Usage: $0 [OPTIONS]"
      echo "OPTIONS:"
      echo "  --skip-landing-zone    Skip landing zone deployment (use existing)"
      echo "  --skip-infra          Skip AKS platform infrastructure deployment (use existing)"
      echo "  --skip-containers     Skip container build and push (use existing images)"
      echo "  --full-rebuild        Perform complete teardown (stacks, RG, KV purge) then deploy fresh"
      echo "  --teardown-only       Perform complete teardown and exit (no deployment)"
      echo "  -h, --help           Show this help message"
      echo ""
      echo "TEARDOWN PROCESS (--full-rebuild and --teardown-only):"
      echo "  1. Uninstall Helm deployments"
      echo "  2. Delete AKS platform stack"
      echo "  3. Delete landing zone stack"
      echo "  4. Delete resource group completely"
      echo "  5. Purge Key Vault (permanent deletion)"
      echo "  6. Clean up local kubectl contexts"
      exit 0 ;;  
    *) 
      echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Configuration
LANDING_ZONE_STACK_NAME="aks-lz-stack"
AKS_PLATFORM_STACK_NAME="aks-platforms-stack"
LOCATION="spaincentral"
LZ_BICEP_FILE="../infra/0-lz/main.bicep"
LZ_PARAMS_FILE="../infra/0-lz/aks-dev.bicepparam"
AKS_BICEP_FILE="../infra/aks10-platform/main.bicep"
AKS_PARAMS_FILE="../infra/aks10-platform/main.bicepparam"
SERVICES=("backend" "frontend")

# 1) Prerequisites
log "INFO" "Checking prerequisites..."
command -v az >/dev/null || { log "ERROR" "az CLI not found"; exit 1; }
command -v docker >/dev/null || { log "ERROR" "docker not found"; exit 1; }
command -v kubectl >/dev/null || { log "ERROR" "kubectl not found"; exit 1; }
command -v helm >/dev/null || { log "ERROR" "helm not found"; exit 1; }
log "INFO" "Prerequisites OK"

# Function to perform full teardown
perform_full_teardown() {
  log "INFO" "Starting full teardown process..."
  
  # Step 1: Delete Helm deployment first (if exists)
  log "INFO" "Checking for existing Helm deployment..."
  if command -v helm >/dev/null && helm list --namespace default 2>/dev/null | grep -q "secret-sharer"; then
    log "INFO" "Uninstalling Helm chart 'secret-sharer'..."
    helm uninstall secret-sharer --namespace default
    log "INFO" "Helm chart uninstalled"
  else
    log "INFO" "No Helm deployment found or helm not available, skipping..."
  fi
  
  # Step 2: Get resource group name and Key Vault info before deleting stacks
  log "INFO" "Retrieving resource information before teardown..."
  LZ_RG_NAME=$(az stack sub show --name "$LANDING_ZONE_STACK_NAME" --query outputs.resourceGroupName.value -o tsv 2>/dev/null || echo "")
  
  # Get Key Vault name from AKS platform stack if it exists
  KEY_VAULT_NAME=""
  if [[ -n "$LZ_RG_NAME" ]] && az stack group show --name "$AKS_PLATFORM_STACK_NAME" --resource-group "$LZ_RG_NAME" >/dev/null 2>&1; then
    KEY_VAULT_NAME=$(az stack group show --name "$AKS_PLATFORM_STACK_NAME" --resource-group "$LZ_RG_NAME" --query outputs.keyvaultName.value -o tsv 2>/dev/null || echo "")
    log "INFO" "Found Key Vault: $KEY_VAULT_NAME"
  fi
  
  # Step 3: Clean up local kubectl context
  log "INFO" "Cleaning up local kubectl context..."
  AKS_NAME="aks-secure-secret-sharer-dev"
  if command -v kubectl >/dev/null && kubectl config get-contexts 2>/dev/null | grep -q "$AKS_NAME"; then
    kubectl config delete-context "$AKS_NAME" 2>/dev/null || true
    log "INFO" "Kubectl context for '$AKS_NAME' removed"
  else
    log "INFO" "No kubectl context found for '$AKS_NAME' or kubectl not available, skipping..."
  fi
  
  # Step 4: Teardown AKS platform stack first
  log "INFO" "Tearing down AKS platform stack..."
  if [[ -n "$LZ_RG_NAME" ]] && az stack group show --name "$AKS_PLATFORM_STACK_NAME" --resource-group "$LZ_RG_NAME" >/dev/null 2>&1; then
    log "INFO" "Deleting AKS platform stack '$AKS_PLATFORM_STACK_NAME' in resource group '$LZ_RG_NAME'..."
    az stack group delete --name "$AKS_PLATFORM_STACK_NAME" --resource-group "$LZ_RG_NAME" --action-on-unmanage detachAll --yes
    log "INFO" "AKS platform stack deleted"
  else
    log "INFO" "AKS platform stack not found, skipping..."
  fi
  
  # Step 5: Teardown landing zone stack
  log "INFO" "Tearing down landing zone stack..."
  if az stack sub show --name "$LANDING_ZONE_STACK_NAME" >/dev/null 2>&1; then
    log "INFO" "Deleting landing zone stack '$LANDING_ZONE_STACK_NAME'..."
    az stack sub delete --name "$LANDING_ZONE_STACK_NAME" --action-on-unmanage detachAll --yes
    log "INFO" "Landing zone stack deleted"
  else
    log "INFO" "Landing zone stack not found, skipping..."
  fi
  
  # Step 6: Delete resource group completely
  if [[ -n "$LZ_RG_NAME" ]]; then
    log "INFO" "Deleting resource group '$LZ_RG_NAME' completely..."
    if az group show --name "$LZ_RG_NAME" >/dev/null 2>&1; then
      az group delete --name "$LZ_RG_NAME" --yes
      log "INFO" "Resource group '$LZ_RG_NAME' successfully deleted"
    else
      log "INFO" "Resource group '$LZ_RG_NAME' not found, skipping..."
    fi
  else
    log "INFO" "No resource group name found, skipping resource group deletion..."
  fi
  
  # Step 7: Purge Key Vault if it exists
  if [[ -n "$KEY_VAULT_NAME" ]]; then
    log "INFO" "Purging Key Vault '$KEY_VAULT_NAME'..."
    # Key Vault purge requires the location, use the same location as deployment
    if az keyvault show-deleted --name "$KEY_VAULT_NAME" --location "$LOCATION" >/dev/null 2>&1; then
      az keyvault purge --name "$KEY_VAULT_NAME" --location "$LOCATION"
      log "INFO" "Key Vault '$KEY_VAULT_NAME' purged successfully"
    else
      log "INFO" "Key Vault '$KEY_VAULT_NAME' not found in deleted state or already purged, skipping..."
    fi
  else
    log "INFO" "No Key Vault name found, skipping Key Vault purge..."
  fi
  
  log "INFO" "Full teardown completed successfully"
}

# Teardown-only mode: delete resources and exit
if [[ "$TEARDOWN_ONLY" == true ]]; then
  log "INFO" "Teardown-only mode: performing full teardown..."
  perform_full_teardown
  log "INFO" "Exiting - no deployment performed"
  exit 0
fi

# Full rebuild teardown
if [[ "$FULL_REBUILD" == true ]]; then
  log "INFO" "Full rebuild requested: performing complete teardown first..."
  perform_full_teardown
  log "INFO" "Teardown completed, proceeding with fresh deployment..."
fi

# 1) Deploy landing zone infrastructure
if [[ "$SKIP_LANDING_ZONE" == false ]]; then
  log "INFO" "Deploying AKS landing zone infrastructure..."
  log "INFO" "This includes resource groups, user-assigned managed identities and GitHub federation..."
  log "INFO" "EXECUTING: az stack sub create"
  az stack sub create --name "$LANDING_ZONE_STACK_NAME" --location "$LOCATION" \
    --template-file "$LZ_BICEP_FILE" --parameters "$LZ_PARAMS_FILE" \
    --deny-settings-mode DenyWriteAndDelete \
    --deny-settings-excluded-actions "Microsoft.App/containerApps/write Microsoft.Authorization/roleAssignments/write" \
    --action-on-unmanage detachAll
  log "INFO" "Landing zone deployment completed"
else
  log "INFO" "Skipping landing zone deployment"
fi

# 2) Deploy AKS platform infrastructure
if [[ "$SKIP_INFRA" == false ]]; then
  log "INFO" "Deploying AKS platform infrastructure (AKS cluster, Application Gateway, networking, etc.)..."
  log "INFO" "This may take 10-15 minutes..."
  log "INFO" "You will see detailed deployment progress below..."
  
  # Get resource group name from landing zone deployment
  log "INFO" "EXECUTING: Get resource group name from landing zone"
  LZ_RG_NAME=$(az stack sub show --name "$LANDING_ZONE_STACK_NAME" --query outputs.resourceGroupName.value -o tsv)
  log "INFO" "Using resource group: $LZ_RG_NAME"
  
  log "INFO" "EXECUTING: az stack group create"
  az stack group create --name "$AKS_PLATFORM_STACK_NAME" --resource-group "$LZ_RG_NAME" \
    --template-file "$AKS_BICEP_FILE" --parameters "$AKS_PARAMS_FILE" \
    --deny-settings-mode None --action-on-unmanage detachAll
  log "INFO" "AKS platform infrastructure deployment completed"
else
  log "INFO" "Skipping AKS platform infrastructure deployment"
fi

# 3) Retrieve outputs from deployments
log "INFO" "Retrieving deployment outputs from Azure..."
log "INFO" "This may take a moment while querying the deployment state..."

# Get resource group name from landing zone deployment
LZ_RG_NAME=$(az stack sub show --name "$LANDING_ZONE_STACK_NAME" --query outputs.resourceGroupName.value -o tsv)

# Core infrastructure outputs from AKS platform stack
AKS_NAME=$(az stack group show --name "$AKS_PLATFORM_STACK_NAME" --resource-group "$LZ_RG_NAME" --query outputs.aksName.value -o tsv)
RESOURCE_GROUP="$LZ_RG_NAME"
ACR_LOGIN_SERVER=$(az stack group show --name "$AKS_PLATFORM_STACK_NAME" --resource-group "$LZ_RG_NAME" --query outputs.acrLoginServer.value -o tsv)
APP_GW_IP=$(az stack group show --name "$AKS_PLATFORM_STACK_NAME" --resource-group "$LZ_RG_NAME" --query outputs.appGwPublicIp.value -o tsv)

# Azure configuration outputs for Helm from AKS platform stack
TENANT_ID=$(az stack group show --name "$AKS_PLATFORM_STACK_NAME" --resource-group "$LZ_RG_NAME" --query outputs.tenantId.value -o tsv)
KEY_VAULT_NAME=$(az stack group show --name "$AKS_PLATFORM_STACK_NAME" --resource-group "$LZ_RG_NAME" --query outputs.keyvaultName.value -o tsv)
BACKEND_UAMI_CLIENT_ID=$(az stack group show --name "$AKS_PLATFORM_STACK_NAME" --resource-group "$LZ_RG_NAME" --query outputs.backendUamiClientId.value -o tsv)
DATABASE_UAMI_CLIENT_ID=$(az stack group show --name "$AKS_PLATFORM_STACK_NAME" --resource-group "$LZ_RG_NAME" --query outputs.dbInitUamiClientId.value -o tsv)
BACKEND_SERVICE_ACCOUNT_NAME=$(az stack group show --name "$AKS_PLATFORM_STACK_NAME" --resource-group "$LZ_RG_NAME" --query outputs.backendK8sServiceAccountName.value -o tsv)
DATABASE_SERVICE_ACCOUNT_NAME=$(az stack group show --name "$AKS_PLATFORM_STACK_NAME" --resource-group "$LZ_RG_NAME" --query outputs.databaseInitK8sServiceAccountName.value -o tsv)

# Cosmos DB configuration outputs
COSMOS_DATABASE_NAME=$(az stack group show --name "$AKS_PLATFORM_STACK_NAME" --resource-group "$LZ_RG_NAME" --query outputs.cosmosDatabaseName.value -o tsv)
COSMOS_CONTAINER_NAME=$(az stack group show --name "$AKS_PLATFORM_STACK_NAME" --resource-group "$LZ_RG_NAME" --query outputs.cosmosContainerName.value -o tsv)
COSMOS_DB_ACCOUNT_NAME=$(az stack group show --name "$AKS_PLATFORM_STACK_NAME" --resource-group "$LZ_RG_NAME" --query outputs.cosmosDbAccountName.value -o tsv)
COSMOS_DB_ENDPOINT="https://${COSMOS_DB_ACCOUNT_NAME}.documents.azure.com:443/"

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
log "INFO" "COSMOS_DATABASE_NAME=$COSMOS_DATABASE_NAME"
log "INFO" "COSMOS_CONTAINER_NAME=$COSMOS_CONTAINER_NAME"
log "INFO" "COSMOS_DB_ACCOUNT_NAME=$COSMOS_DB_ACCOUNT_NAME"
log "INFO" "COSMOS_DB_ENDPOINT=$COSMOS_DB_ENDPOINT"

# 4) Build & push container images
if [[ "$SKIP_CONTAINERS" == false ]]; then
  log "INFO" "Logging into Azure Container Registry..."
  ACR_NAME="${ACR_LOGIN_SERVER%%.*}"
  log "INFO" "EXECUTING: az acr login"
  az acr login --name "$ACR_NAME" --verbose
  log "INFO" "Building and pushing container images..."
  IMAGES=()
  for svc in "${SERVICES[@]}"; do
    TAG_VAR="${svc^^}_TAG"
    TAG_VALUE="${!TAG_VAR:-latest}"
    IMAGE="$ACR_LOGIN_SERVER/secure-secret-sharer-$svc:$TAG_VALUE"
    log "INFO" "Building $svc image ($TAG_VALUE) - this may take several minutes..."
    log "INFO" "EXECUTING: docker build"
    docker build -t "$IMAGE" "../$svc" --progress=plain
    log "INFO" "Pushing $svc image to ACR..."
    log "INFO" "EXECUTING: docker push"
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
log "INFO" "EXECUTING: az aks get-credentials"
az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$AKS_NAME" --overwrite-existing --verbose
log "INFO" "Setting kubectl context..."
log "INFO" "EXECUTING: kubectl config use-context"
kubectl config use-context "$AKS_NAME"
log "INFO" "Verifying cluster connection..."
log "INFO" "EXECUTING: kubectl get nodes"
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
log "INFO" "EXECUTING: helm upgrade --install"
log "INFO" "=============================================="
log "INFO" "ENVIRONMENT VARIABLES BEING PASSED TO BACKEND:"
log "INFO" "- AZURE_CLIENT_ID: $BACKEND_UAMI_CLIENT_ID"
log "INFO" "- AZURE_TENANT_ID: $TENANT_ID"
log "INFO" "- COSMOS_ENDPOINT: $COSMOS_DB_ENDPOINT"
log "INFO" "- COSMOS_DATABASE_NAME: $COSMOS_DATABASE_NAME"
log "INFO" "- COSMOS_CONTAINER_NAME: $COSMOS_CONTAINER_NAME"
log "INFO" "- USE_MANAGED_IDENTITY: true"
log "INFO" "- FLASK_APP: app/main.py"
log "INFO" "- FLASK_ENV: production"
log "INFO" "- AZURE_LOG_LEVEL: INFO"
log "INFO" "- PYTHONUNBUFFERED: 1"
log "INFO" "=============================================="
log "INFO" "COPY-PASTE COMMAND (with actual values):"
echo "helm upgrade --install secret-sharer ../k8s/secret-sharer-app \\"
echo "  --namespace default --create-namespace \\"
echo "  --set backend.keyVault.name=\"$KEY_VAULT_NAME\" \\"
echo "  --set backend.keyVault.tenantId=\"$TENANT_ID\" \\"
echo "  --set backend.keyVault.userAssignedIdentityClientID=\"$BACKEND_UAMI_CLIENT_ID\" \\"
echo "  --set backend.serviceAccount.name=\"$BACKEND_SERVICE_ACCOUNT_NAME\" \\"
echo "  --set database.serviceAccount.azureClientId=\"$DATABASE_UAMI_CLIENT_ID\" \\"
echo "  --set database.serviceAccount.name=\"$DATABASE_SERVICE_ACCOUNT_NAME\" \\"
echo "  --set backend.image.tag=\"$BACKEND_TAG\" \\"
echo "  --set frontend.image.tag=\"$FRONTEND_TAG\" \\"
echo "  --set acrLoginServer=\"$ACR_LOGIN_SERVER\" \\"
echo "  --set cosmosdb.endpoint=\"$COSMOS_DB_ENDPOINT\" \\"
echo "  --set cosmosdb.databaseName=\"$COSMOS_DATABASE_NAME\" \\"
echo "  --set cosmosdb.containerName=\"$COSMOS_CONTAINER_NAME\" \\"
echo "  --set backend.env.AZURE_CLIENT_ID=\"$BACKEND_UAMI_CLIENT_ID\" \\"
echo "  --timeout=15m \\"
echo "  --wait \\"
echo "  --debug"
log "INFO" "=============================================="
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
  --set cosmosdb.endpoint="$COSMOS_DB_ENDPOINT" \
  --set cosmosdb.databaseName="$COSMOS_DATABASE_NAME" \
  --set cosmosdb.containerName="$COSMOS_CONTAINER_NAME" \
  --set backend.env.AZURE_CLIENT_ID="$BACKEND_UAMI_CLIENT_ID" \
  --timeout=15m \
  --wait \
  --debug || {
    log "ERROR" "Helm deployment failed! Running diagnostics..."
    log "INFO" "EXECUTING: kubectl get pods"
    kubectl get pods -o wide
    log "INFO" "EXECUTING: kubectl get events"
    kubectl get events --sort-by=.metadata.creationTimestamp --field-selector type!=Normal
    log "INFO" "EXECUTING: kubectl describe pods (backend)"
    kubectl describe pods -l app.kubernetes.io/name=backend || true
    log "INFO" "EXECUTING: kubectl logs (backend)"
    kubectl logs -l app.kubernetes.io/name=backend --all-containers=true --previous=false || true
    log "INFO" "EXECUTING: kubectl get services"
    kubectl get services
    log "INFO" "EXECUTING: kubectl get ingress"
    kubectl get ingress
    log "ERROR" "Helm deployment failed - see diagnostics above"
    exit 1
  }

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