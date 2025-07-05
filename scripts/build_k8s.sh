#!/usr/bin/env bash
set -euo pipefail

# build_k8s.sh - AKS deployment for Secure Secret Sharer on Azure Kubernetes Service
# This script leverages the modular landing zone deployment with proper deployment sequence:
# 1. Landing Zone (shared infrastructure + networking)
# 2. Bootstrap Key Vault (platform-specific secrets management)
# 3. Key Vault Seeding (generate and store Fernet encryption keys)
# 4. Platform Infrastructure (AKS cluster, Application Gateway, networking, etc.)
# 5. Container Images (build and push to ACR)
# 6. Workload Applications (Helm chart deployment to AKS)
# 
# NOTE: This script has been updated to work with the new folder structure:
# - Backend: src/backend/ (contains Dockerfile and backend code)
# - Frontend: src/frontend/ (contains frontend code)
# - Helm Charts: deploy/helm/ (contains Kubernetes manifests and Helm chart)
# - Infrastructure: infra/ (unchanged)
#
# NOTE: After folder structure changes (from 01-bootstrap-kv to 10-bootstrap-kv), the deploy-landing-zone.sh 
# script may reference old folder paths. If landing zone deployment fails, use --skip-landing-zone
# and manually deploy the landing zone using the 0-landing-zone/ folder.
#
# Usage: ./build_k8s.sh [--skip-landing-zone] [--skip-bootstrap-kv] [--skip-key-seeding] [--skip-infra] [--skip-containers] [--full-rebuild] [--teardown-only]

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
    az deployment operation group list --name "$deployment_name" --resource-group "$resource_group" --query '[?properties.provisioningState==`Failed`].{Operation:properties.targetResource.resourceName, Error:properties.statusMessage.error.message}' -o table 2>/dev/null || true
  else
    # Subscription deployment  
    log "INFO" "Getting subscription deployment errors for: $deployment_name"
    az deployment sub show --name "$deployment_name" --query 'properties.error' -o json 2>/dev/null || true
    az deployment operation sub list --name "$deployment_name" --query '[?properties.provisioningState==`Failed`].{Operation:properties.targetResource.resourceName, Error:properties.statusMessage.error.message}' -o table 2>/dev/null || true
  fi
}

# =====================
# Configurable Variables
# =====================
BACKEND_TAG="0.3.0"
FRONTEND_TAG="0.3.0"

SKIP_LANDING_ZONE=false
SKIP_BOOTSTRAP_KV=false
SKIP_KEY_SEEDING=false
SKIP_INFRA=false
SKIP_CONTAINERS=false
FULL_REBUILD=false
TEARDOWN_ONLY=false

# Parse flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-landing-zone) SKIP_LANDING_ZONE=true; shift ;;
    --skip-bootstrap-kv) SKIP_BOOTSTRAP_KV=true; shift ;;
    --skip-key-seeding) SKIP_KEY_SEEDING=true; shift ;;
    --skip-infra) SKIP_INFRA=true; shift ;;
    --skip-containers) SKIP_CONTAINERS=true; shift ;;
    --full-rebuild) FULL_REBUILD=true; shift ;;
    --teardown-only) TEARDOWN_ONLY=true; shift ;;
    -h|--help)
      echo "Usage: $0 [--skip-landing-zone] [--skip-bootstrap-kv] [--skip-key-seeding] [--skip-infra] [--skip-containers] [--full-rebuild] [--teardown-only]"
      echo "OPTIONS:"
      echo "  --skip-landing-zone    Skip landing zone deployment (use existing)"
      echo "  --skip-bootstrap-kv    Skip bootstrap Key Vault deployment (use existing)"
      echo "  --skip-key-seeding     Skip encryption key generation and seeding"
      echo "  --skip-infra          Skip AKS platform infrastructure deployment (use existing)"
      echo "  --skip-containers     Skip container build and push (use existing images)"
      echo "  --full-rebuild        Perform complete teardown then deploy fresh"
      echo "  --teardown-only       Perform complete teardown and exit (no deployment)"
      echo "  -h, --help           Show this help message"
      echo ""
      echo "TEARDOWN PROCESS (--full-rebuild and --teardown-only):"
      echo "  1. Uninstall Helm deployments"
      echo "  2. Delete AKS platform deployment"
      echo "  3. Delete bootstrap Key Vault deployment"
      echo "  4. Delete resource group completely"
      echo "  5. Purge Key Vault (permanent deletion)"
      echo "  6. Clean up local kubectl contexts"
      exit 0 ;;
    *)
      echo "Unknown option: $1"; exit 1 ;;
  esac
done

# =====================
# Deployment Names & Paths
# =====================
LOCATION="spaincentral"
SERVICES=("backend" "frontend")

# Bootstrap Key Vault Deployment
BOOTSTRAP_KV_DEPLOYMENT_NAME="Secure-Sharer-Bootstrap-KV"
BOOTSTRAP_KV_BICEP_FILE="../infra/10-bootstrap-kv/main.bicep"
BOOTSTRAP_KV_PARAMS_FILE="../infra/10-bootstrap-kv/aks.dev.bicepparam"

# Platform Infrastructure Deployment (AKS)
PLATFORM_DEPLOYMENT_NAME="Secure-Sharer-Platform-AKS"
PLATFORM_BICEP_FILE="../infra/20-platform-aks/main.bicep"
PLATFORM_PARAMS_FILE="../infra/20-platform-aks/main.bicepparam"

# =====================
# Prerequisites
# =====================
log "INFO" "Checking prerequisites..."
command -v az >/dev/null || { log "ERROR" "az CLI not found"; exit 1; }
command -v docker >/dev/null || { log "ERROR" "docker not found"; exit 1; }
command -v kubectl >/dev/null || { log "ERROR" "kubectl not found"; exit 1; }
command -v helm >/dev/null || { log "ERROR" "helm not found"; exit 1; }

# Check OpenSSL availability (needed for Key Vault seeding)
if ! command -v openssl >/dev/null 2>&1; then
  log "ERROR" "OpenSSL not found. OpenSSL is required for generating encryption keys"
  log "ERROR" "On Windows: Install Git for Windows (includes OpenSSL) or OpenSSL directly"
  log "ERROR" "On Linux/macOS: Install openssl package"
  exit 1
fi

log "INFO" "Prerequisites OK"

# =====================
# Teardown Logic
# =====================
if [[ "$TEARDOWN_ONLY" == true ]]; then
  log "INFO" "Teardown-only mode: deleting all deployments and resources..."
  
  # Use actual resource group name for teardown
  ACTUAL_RESOURCE_GROUP="ss-d-aks-rg"
  
  # Step 1: Uninstall Helm deployments first
  log "INFO" "Step 1: Checking for existing Helm deployment..."
  if command -v helm >/dev/null && helm list --namespace default 2>/dev/null | grep -q "secret-sharer"; then
    log "INFO" "Uninstalling Helm chart 'secret-sharer'..."
    helm uninstall secret-sharer --namespace default
    log "INFO" "✅ Helm chart uninstalled"
  else
    log "INFO" "No Helm deployment found or helm not available, skipping..."
  fi
  
  # Step 2: Clean up local kubectl context
  log "INFO" "Step 2: Cleaning up local kubectl context..."
  AKS_NAME="aks-secure-secret-sharer-dev"
  if command -v kubectl >/dev/null && kubectl config get-contexts 2>/dev/null | grep -q "$AKS_NAME"; then
    kubectl config delete-context "$AKS_NAME" 2>/dev/null || true
    log "INFO" "✅ Kubectl context for '$AKS_NAME' removed"
  else
    log "INFO" "No kubectl context found for '$AKS_NAME' or kubectl not available, skipping..."
  fi
  
  # Step 3: Check if Key Vault exists in the resource group and delete it
  log "INFO" "Step 3: Checking for Key Vault in resource group: $ACTUAL_RESOURCE_GROUP"
  KEY_VAULT_NAME=""
  
  if az group show --name "$ACTUAL_RESOURCE_GROUP" >/dev/null 2>&1; then
    # Get the first Key Vault in the resource group (should only be one for this project)
    KEY_VAULT_NAME=$(az keyvault list --resource-group "$ACTUAL_RESOURCE_GROUP" --query '[0].name' -o tsv 2>/dev/null || echo "")
    
    if [[ -n "$KEY_VAULT_NAME" && "$KEY_VAULT_NAME" != "null" ]]; then
      log "INFO" "Found Key Vault: $KEY_VAULT_NAME"
      log "INFO" "Deleting Key Vault: $KEY_VAULT_NAME (waiting for completion)"
      az keyvault delete --name "$KEY_VAULT_NAME" --resource-group "$ACTUAL_RESOURCE_GROUP" 2>/dev/null || true
      
      # Wait for Key Vault deletion to complete
      log "INFO" "Waiting for Key Vault $KEY_VAULT_NAME to be fully deleted..."
      while az keyvault show --name "$KEY_VAULT_NAME" --resource-group "$ACTUAL_RESOURCE_GROUP" >/dev/null 2>&1; do
        log "INFO" "Key Vault $KEY_VAULT_NAME still exists, waiting 10 seconds..."
        sleep 10
      done
      log "INFO" "✅ Key Vault $KEY_VAULT_NAME deleted successfully"
      
      # Step 4: Attempt to purge the Key Vault (background)
      log "INFO" "Step 4: Attempting to purge Key Vault: $KEY_VAULT_NAME (background)"
      (
        if az keyvault purge --name "$KEY_VAULT_NAME" --location "$LOCATION" 2>/dev/null; then
          echo "[$(date '+%Y-%m-%dT%H:%M:%S') INFO] ✅ Key Vault $KEY_VAULT_NAME purged successfully"
        else
          echo "[$(date '+%Y-%m-%dT%H:%M:%S') WARNING] ❌ Failed to purge Key Vault $KEY_VAULT_NAME (likely due to purge protection)"
          echo "[$(date '+%Y-%m-%dT%H:%M:%S') WARNING] Key Vault will remain in soft-deleted state for 90 days"
        fi
      ) &
      PURGE_PID=$!
    else
      log "INFO" "No Key Vault found in resource group"
      PURGE_PID=""
    fi
  else
    log "INFO" "Resource group $ACTUAL_RESOURCE_GROUP does not exist"
    PURGE_PID=""
  fi
  
  # Delete deployments first (synchronously)
  log "INFO" "Deleting platform deployment..."
  az deployment group delete --name "$PLATFORM_DEPLOYMENT_NAME" --resource-group "$ACTUAL_RESOURCE_GROUP" --verbose 2>/dev/null || true
  
  log "INFO" "Deleting bootstrap Key Vault deployment..."
  az deployment group delete --name "$BOOTSTRAP_KV_DEPLOYMENT_NAME" --resource-group "$ACTUAL_RESOURCE_GROUP" --verbose 2>/dev/null || true
  
  # Step 5: Start resource group deletion in background
  log "INFO" "Step 5: Starting resource group deletion: $ACTUAL_RESOURCE_GROUP (background)"
  if az group show --name "$ACTUAL_RESOURCE_GROUP" >/dev/null 2>&1; then
    az group delete --name "$ACTUAL_RESOURCE_GROUP" --yes --no-wait --verbose 2>/dev/null &
    RG_DELETE_PID=$!
    
    # Step 6: Wait for Key Vault purge and resource group deletion to complete
    if [[ -n "$PURGE_PID" ]]; then
      log "INFO" "Step 6: Waiting for Key Vault purge operation to complete..."
      wait "$PURGE_PID" 2>/dev/null || true
      log "INFO" "✅ Key Vault purge operation completed"
    fi
    
    log "INFO" "Waiting for resource group deletion to complete..."
    if kill -0 "$RG_DELETE_PID" 2>/dev/null; then
      wait "$RG_DELETE_PID" 2>/dev/null || true
    fi
    
    # Verify resource group deletion
    log "INFO" "Verifying resource group deletion..."
    while az group show --name "$ACTUAL_RESOURCE_GROUP" >/dev/null 2>&1; do
      log "INFO" "Resource group $ACTUAL_RESOURCE_GROUP still exists, waiting 15 seconds..."
      sleep 15
    done
    log "INFO" "✅ Resource group $ACTUAL_RESOURCE_GROUP deleted successfully"
  else
    log "INFO" "Resource group $ACTUAL_RESOURCE_GROUP does not exist, skipping..."
  fi
  
  # Skip landing zone teardown as it looks for wrong resource group names
  log "INFO" "Skipping landing zone teardown (looks for non-existent resource groups)"
  log "INFO" "Teardown completed successfully"
  exit 0
fi

if [[ "$FULL_REBUILD" == true ]]; then
  log "INFO" "Full rebuild requested: tearing down all deployments and resources..."
  
  # Use actual resource group name for teardown
  ACTUAL_RESOURCE_GROUP="ss-d-aks-rg"
  
  # Step 1: Uninstall Helm deployments first
  log "INFO" "Step 1: Checking for existing Helm deployment..."
  if command -v helm >/dev/null && helm list --namespace default 2>/dev/null | grep -q "secret-sharer"; then
    log "INFO" "Uninstalling Helm chart 'secret-sharer'..."
    helm uninstall secret-sharer --namespace default
    log "INFO" "✅ Helm chart uninstalled"
  else
    log "INFO" "No Helm deployment found or helm not available, skipping..."
  fi
  
  # Step 2: Clean up local kubectl context
  log "INFO" "Step 2: Cleaning up local kubectl context..."
  AKS_NAME="aks-secure-secret-sharer-dev"
  if command -v kubectl >/dev/null && kubectl config get-contexts 2>/dev/null | grep -q "$AKS_NAME"; then
    kubectl config delete-context "$AKS_NAME" 2>/dev/null || true
    log "INFO" "✅ Kubectl context for '$AKS_NAME' removed"
  else
    log "INFO" "No kubectl context found for '$AKS_NAME' or kubectl not available, skipping..."
  fi
  
  # Step 3: Check if Key Vault exists in resource group and handle it
  log "INFO" "Step 3: Checking for Key Vault in resource group: $ACTUAL_RESOURCE_GROUP"
  KEY_VAULT_NAME=""
  PURGE_PID=""
  
  if az group show --name "$ACTUAL_RESOURCE_GROUP" >/dev/null 2>&1; then
    # Get the Key Vault in the resource group (should be only one)
    KEY_VAULT_NAME=$(az keyvault list --resource-group "$ACTUAL_RESOURCE_GROUP" --query '[0].name' -o tsv 2>/dev/null || echo "")
    
    if [[ -n "$KEY_VAULT_NAME" && "$KEY_VAULT_NAME" != "null" ]]; then
      log "INFO" "Found Key Vault: $KEY_VAULT_NAME"
      log "INFO" "Deleting Key Vault: $KEY_VAULT_NAME"
      az keyvault delete --name "$KEY_VAULT_NAME" --resource-group "$ACTUAL_RESOURCE_GROUP" 2>/dev/null || true
      
      # Wait for deletion to complete
      log "INFO" "Waiting for Key Vault deletion to complete..."
      while az keyvault show --name "$KEY_VAULT_NAME" --resource-group "$ACTUAL_RESOURCE_GROUP" >/dev/null 2>&1; do
        log "INFO" "Key Vault still exists, waiting 10 seconds..."
        sleep 10
      done
      log "INFO" "✅ Key Vault deleted successfully"
      
      # Start purge in background
      log "INFO" "Starting Key Vault purge in background..."
      (
        if az keyvault purge --name "$KEY_VAULT_NAME" --location "$LOCATION" 2>/dev/null; then
          echo "[$(date '+%Y-%m-%dT%H:%M:%S') INFO] ✅ Key Vault $KEY_VAULT_NAME purged successfully"
        else
          echo "[$(date '+%Y-%m-%dT%H:%M:%S') WARNING] ❌ Failed to purge Key Vault $KEY_VAULT_NAME"
        fi
      ) &
      PURGE_PID=$!
    else
      log "INFO" "No Key Vault found in resource group"
    fi
  else
    log "INFO" "Resource group $ACTUAL_RESOURCE_GROUP does not exist"
  fi
  
  # Delete deployments first (synchronously)
  log "INFO" "Deleting platform deployment..."
  az deployment group delete --name "$PLATFORM_DEPLOYMENT_NAME" --resource-group "$ACTUAL_RESOURCE_GROUP" --verbose 2>/dev/null || true
  
  log "INFO" "Deleting bootstrap Key Vault deployment..."
  az deployment group delete --name "$BOOTSTRAP_KV_DEPLOYMENT_NAME" --resource-group "$ACTUAL_RESOURCE_GROUP" --verbose 2>/dev/null || true
  
  # Step 4: Start resource group deletion in background
  log "INFO" "Step 4: Starting resource group deletion: $ACTUAL_RESOURCE_GROUP (background)"
  if az group show --name "$ACTUAL_RESOURCE_GROUP" >/dev/null 2>&1; then
    az group delete --name "$ACTUAL_RESOURCE_GROUP" --yes --no-wait --verbose 2>/dev/null &
    RG_DELETE_PID=$!
    
    # Step 5: Wait for Key Vault purge and resource group deletion to complete
    if [[ -n "$PURGE_PID" ]]; then
      log "INFO" "Step 5: Waiting for Key Vault purge operation to complete..."
      wait "$PURGE_PID" 2>/dev/null || true
      log "INFO" "✅ Key Vault purge operation completed"
    fi
    
    log "INFO" "Waiting for resource group deletion to complete..."
    if kill -0 "$RG_DELETE_PID" 2>/dev/null; then
      wait "$RG_DELETE_PID" 2>/dev/null || true
    fi
    
    # Verify resource group deletion
    log "INFO" "Verifying resource group deletion..."
    while az group show --name "$ACTUAL_RESOURCE_GROUP" >/dev/null 2>&1; do
      log "INFO" "Resource group $ACTUAL_RESOURCE_GROUP still exists, waiting 15 seconds..."
      sleep 15
    done
    log "INFO" "✅ Resource group $ACTUAL_RESOURCE_GROUP deleted successfully"
  else
    log "INFO" "Resource group $ACTUAL_RESOURCE_GROUP does not exist, skipping..."
  fi
  
  # Skip landing zone teardown as it looks for wrong resource group names  
  log "INFO" "Skipping landing zone teardown (looks for non-existent resource groups)"
  log "INFO" "Teardown completed"
fi

# =====================
# 1. Deploy Landing Zone (Shared Infrastructure)
# =====================
if [[ "$SKIP_LANDING_ZONE" == false ]]; then
  log "INFO" "Deploying landing zone (shared infrastructure + networking)..."
  log "INFO" "This includes user-assigned managed identities and GitHub federation..."
  log "INFO" "Note: Landing zone now uses 0-landing-zone/ folder structure"
  ./deploy-landing-zone.sh k8s
  log "INFO" "Landing zone deployment completed"
else
  log "INFO" "Skipping landing zone deployment"
fi

# =====================
# 1.1. Retrieve Landing Zone Resource Group
# =====================
log "INFO" "Retrieving resource group from landing zone deployment..."

# Get the most recent landing zone deployment
RECENT_LZ_DEPLOYMENT=$(az deployment sub list \
  --query "sort_by([?contains(name, 'landing-zone-k8s')], &properties.timestamp) | [-1].name" \
  -o tsv)

if [[ -z "$RECENT_LZ_DEPLOYMENT" || "$RECENT_LZ_DEPLOYMENT" == "null" ]]; then
  log "ERROR" "Could not find recent landing zone deployment"
  log "ERROR" "Please ensure landing zone was deployed successfully"
  exit 1
fi

log "INFO" "Found recent landing zone deployment: $RECENT_LZ_DEPLOYMENT"

# Try to get resource group from landing zone deployment outputs
LANDING_ZONE_RESOURCE_GROUP=$(az deployment sub show \
  --name "$RECENT_LZ_DEPLOYMENT" \
  --query "properties.outputs.resourceGroupName.value" \
  -o tsv 2>/dev/null || echo "")

if [[ -z "$LANDING_ZONE_RESOURCE_GROUP" || "$LANDING_ZONE_RESOURCE_GROUP" == "null" ]]; then
  # Fallback: use naming convention from the landing zone
  LANDING_ZONE_RESOURCE_GROUP="ss-d-aks-rg"
  log "WARNING" "Could not retrieve resource group from deployment outputs"
  log "INFO" "Using default resource group name: $LANDING_ZONE_RESOURCE_GROUP"
else
  log "INFO" "Retrieved resource group from landing zone: $LANDING_ZONE_RESOURCE_GROUP"
fi

# Verify the resource group exists
if ! az group show --name "$LANDING_ZONE_RESOURCE_GROUP" >/dev/null 2>&1; then
  log "ERROR" "Resource group '$LANDING_ZONE_RESOURCE_GROUP' does not exist"
  log "ERROR" "Landing zone deployment may have failed or used different naming"
  exit 1
fi



# =====================
# 2. Deploy Bootstrap Key Vault 
# =====================
if [[ "$SKIP_BOOTSTRAP_KV" == false ]]; then
  log "INFO" "Deploying Bootstrap Key Vault for AKS platform..."
  log "INFO" "This creates the platform-specific Key Vault that will be used by the platform infrastructure..."
  log "INFO" "Target resource group: $LANDING_ZONE_RESOURCE_GROUP"
  
  # =====================
  # 2.0. Check for and recover soft-deleted Key Vault
  # =====================
  log "INFO" "Checking for existing soft-deleted Key Vault..."
  
  # First, we need to determine what the Key Vault name will be based on the bicep parameters
  # Read the expected Key Vault name from the naming convention
  EXPECTED_KV_NAME="ssdakskv"  # Based on actual naming convention used in bicep template
  
  # Check if a Key Vault with this name exists in soft-deleted state
  DELETED_KV_INFO=$(az keyvault list-deleted --query "[?name=='$EXPECTED_KV_NAME' && location=='$LOCATION']" -o json 2>/dev/null || echo "[]")
  
  if [[ "$DELETED_KV_INFO" != "[]" && "$DELETED_KV_INFO" != "" ]]; then
    log "WARNING" "Found soft-deleted Key Vault: $EXPECTED_KV_NAME"
    log "INFO" "Attempting to purge soft-deleted Key Vault first..."
    
    if az keyvault purge --name "$EXPECTED_KV_NAME" --location "$LOCATION" 2>/dev/null; then
      log "INFO" "✅ Successfully purged soft-deleted Key Vault: $EXPECTED_KV_NAME"
      log "INFO" "Waiting 60 seconds for purge to complete..."
      sleep 60
      log "INFO" "Proceeding with Bicep deployment"
    else
      log "WARNING" "Failed to purge soft-deleted Key Vault: $EXPECTED_KV_NAME"
      log "INFO" "Attempting to recover soft-deleted Key Vault instead..."
      
      if az keyvault recover --name "$EXPECTED_KV_NAME" --location "$LOCATION" 2>/dev/null; then
        log "INFO" "✅ Successfully recovered soft-deleted Key Vault: $EXPECTED_KV_NAME"
        log "INFO" "Waiting 30 seconds for recovery to complete..."
        sleep 30
        
        # Set the Bootstrap KV name since we recovered it
        BOOTSTRAP_KV_NAME="$EXPECTED_KV_NAME"
        log "INFO" "Proceeding with Bicep deployment to apply any configuration updates"
      else
        log "ERROR" "Failed to both purge and recover soft-deleted Key Vault: $EXPECTED_KV_NAME"
        log "ERROR" "Manual intervention required - manually purge or recover the Key Vault"
        log "ERROR" "Recovery command: az keyvault recover --name '$EXPECTED_KV_NAME' --location '$LOCATION'"
        log "ERROR" "Purge command: az keyvault purge --name '$EXPECTED_KV_NAME' --location '$LOCATION'"
        exit 1
      fi
    fi
  else
    log "INFO" "No soft-deleted Key Vault found for name: $EXPECTED_KV_NAME"
    log "INFO" "Proceeding with Bicep deployment"
  fi
  
  # Always attempt Bicep deployment (regardless of purge/recovery outcome)
  # This ensures any Key Vault configuration updates are applied
  log "INFO" "Deploying Key Vault via Bicep template..."
  if ! az deployment group create \
    --template-file "$BOOTSTRAP_KV_BICEP_FILE" \
    --parameters "$BOOTSTRAP_KV_PARAMS_FILE" \
    --resource-group "$LANDING_ZONE_RESOURCE_GROUP" \
    --name "$BOOTSTRAP_KV_DEPLOYMENT_NAME" \
    --no-prompt \
    --verbose; then
    log "ERROR" "Bootstrap Key Vault deployment failed"
    get_deployment_errors "$BOOTSTRAP_KV_DEPLOYMENT_NAME" "$LANDING_ZONE_RESOURCE_GROUP"
    
    # Check if the error is related to soft-delete conflict
    log "INFO" "Checking if deployment failed due to soft-delete conflict..."
    DEPLOYMENT_ERROR=$(az deployment group show --name "$BOOTSTRAP_KV_DEPLOYMENT_NAME" --resource-group "$LANDING_ZONE_RESOURCE_GROUP" --query 'properties.error' -o json 2>/dev/null || echo "{}")
    
    # Also get the detailed deployment operations to check for specific Key Vault errors
    DEPLOYMENT_OPERATIONS=$(az deployment operation group list --name "$BOOTSTRAP_KV_DEPLOYMENT_NAME" --resource-group "$LANDING_ZONE_RESOURCE_GROUP" --query '[?properties.provisioningState==`Failed`]' -o json 2>/dev/null || echo "[]")
    
    # Extract the full error message including nested details
    if command -v jq >/dev/null 2>&1; then
      FULL_ERROR_TEXT=$(echo "$DEPLOYMENT_ERROR" | jq -r 'tostring' 2>/dev/null || echo "$DEPLOYMENT_ERROR")
      OPERATIONS_TEXT=$(echo "$DEPLOYMENT_OPERATIONS" | jq -r 'tostring' 2>/dev/null || echo "$DEPLOYMENT_OPERATIONS")
      COMBINED_ERROR_TEXT="$FULL_ERROR_TEXT $OPERATIONS_TEXT"
    else
      # Fallback without jq - just use the raw JSON
      FULL_ERROR_TEXT="$DEPLOYMENT_ERROR"
      OPERATIONS_TEXT="$DEPLOYMENT_OPERATIONS"
      COMBINED_ERROR_TEXT="$FULL_ERROR_TEXT $OPERATIONS_TEXT"
    fi
    
    log "DEBUG" "Full deployment error: $FULL_ERROR_TEXT"
    log "DEBUG" "Deployment operations: $OPERATIONS_TEXT"
    
    # Check for soft-delete related errors in both the main error and the operations
    if [[ "$COMBINED_ERROR_TEXT" =~ "soft delete" ]] || [[ "$COMBINED_ERROR_TEXT" =~ "same name already exists in deleted state" ]] || [[ "$COMBINED_ERROR_TEXT" =~ "ConflictError" ]] || [[ "$COMBINED_ERROR_TEXT" =~ "vault with the same name already exists in deleted state" ]]; then
      log "WARNING" "Deployment failed due to soft-delete conflict"
      log "INFO" "Attempting Key Vault purge first, then recovery if purge fails..."
      
      if az keyvault purge --name "$EXPECTED_KV_NAME" --location "$LOCATION" 2>/dev/null; then
        log "INFO" "✅ Successfully purged Key Vault: $EXPECTED_KV_NAME"
        log "INFO" "Waiting 60 seconds for purge to complete..."
        sleep 60
        
        # Retry the Bicep deployment after purge
        log "INFO" "Retrying Bicep deployment after purge..."
        if az deployment group create \
          --template-file "$BOOTSTRAP_KV_BICEP_FILE" \
          --parameters "$BOOTSTRAP_KV_PARAMS_FILE" \
          --resource-group "$LANDING_ZONE_RESOURCE_GROUP" \
          --name "$BOOTSTRAP_KV_DEPLOYMENT_NAME-retry" \
          --no-prompt \
          --verbose; then
          log "INFO" "✅ Bootstrap Key Vault deployment succeeded after purge"
          
          # Retrieve Key Vault name from the retry deployment
          BOOTSTRAP_KV_NAME=$(az deployment group show \
            --name "$BOOTSTRAP_KV_DEPLOYMENT_NAME-retry" \
            --resource-group "$LANDING_ZONE_RESOURCE_GROUP" \
            --query properties.outputs.keyVaultName.value -o tsv)
        else
          log "ERROR" "Bootstrap Key Vault deployment failed even after purge"
          exit 1
        fi
      else
        log "WARNING" "Failed to purge Key Vault: $EXPECTED_KV_NAME"
        log "INFO" "Attempting Key Vault recovery as fallback..."
        
        if az keyvault recover --name "$EXPECTED_KV_NAME" --location "$LOCATION" 2>/dev/null; then
          log "INFO" "✅ Successfully recovered Key Vault after deployment failure"
          BOOTSTRAP_KV_NAME="$EXPECTED_KV_NAME"
          log "INFO" "Waiting 30 seconds for recovery to complete..."
          sleep 30
        else
          log "ERROR" "Failed to both purge and recover Key Vault: $EXPECTED_KV_NAME"
          log "ERROR" "Manual intervention required - manually purge or recover the Key Vault"
          log "ERROR" "Recovery command: az keyvault recover --name '$EXPECTED_KV_NAME' --location '$LOCATION'"
          log "ERROR" "Purge command: az keyvault purge --name '$EXPECTED_KV_NAME' --location '$LOCATION'"
          exit 1
        fi
      fi
    else
      log "ERROR" "Deployment failed for reasons other than soft-delete conflict"
      log "ERROR" "Error details: $FULL_ERROR_TEXT"
      exit 1
    fi
  else
    log "INFO" "Bootstrap Key Vault deployment completed"
    
    # Retrieve Key Vault name from deployment outputs (or use existing if already set from recovery)
    if [[ -z "${BOOTSTRAP_KV_NAME:-}" ]]; then
      log "INFO" "Retrieving Key Vault name from Bootstrap deployment..."
      BOOTSTRAP_KV_NAME=$(az deployment group show \
        --name "$BOOTSTRAP_KV_DEPLOYMENT_NAME" \
        --resource-group "$LANDING_ZONE_RESOURCE_GROUP" \
        --query properties.outputs.keyVaultName.value -o tsv)
      
      if [[ -z "$BOOTSTRAP_KV_NAME" || "$BOOTSTRAP_KV_NAME" == "null" ]]; then
        log "ERROR" "Failed to retrieve Key Vault name from Bootstrap deployment"
        exit 1
      fi
    else
      log "INFO" "Using Key Vault name from recovery: $BOOTSTRAP_KV_NAME"
    fi
  fi
  
  log "INFO" "Bootstrap Key Vault name: $BOOTSTRAP_KV_NAME"
  
  # =====================
  # 2.1. Setup Key Vault Permissions
  # =====================
  log "INFO" "Setting up Key Vault permissions for current user..."
  log "INFO" "This ensures you have the necessary permissions to manage secrets..."
  
  # Get current account information
  ACCOUNT_TYPE=$(az account show --query user.type -o tsv 2>/dev/null || echo "")
  ACCOUNT_NAME=$(az account show --query user.name -o tsv 2>/dev/null || echo "")
  
  log "INFO" "Current account: $ACCOUNT_NAME (type: $ACCOUNT_TYPE)"
  
  # Try to get user object ID based on account type
  if [[ "$ACCOUNT_TYPE" == "user" ]]; then
    # For user accounts, try different methods to get object ID
    USER_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv 2>/dev/null || echo "")
    
    if [[ -z "$USER_OBJECT_ID" || "$USER_OBJECT_ID" == "null" ]]; then
      log "WARNING" "Failed to get object ID via signed-in-user, trying user lookup..."
      USER_OBJECT_ID=$(az ad user show --id "$ACCOUNT_NAME" --query id -o tsv 2>/dev/null || echo "")
    fi
  else
    # For service principals or other account types
    log "INFO" "Non-user account detected, attempting to get principal ID..."
    USER_OBJECT_ID=$(az account show --query user.name -o tsv 2>/dev/null || echo "")
  fi
  
  if [[ -z "$USER_OBJECT_ID" || "$USER_OBJECT_ID" == "null" ]]; then
    log "ERROR" "Failed to retrieve current user/principal object ID"
    log "ERROR" "Account name: $ACCOUNT_NAME"
    log "ERROR" "Account type: $ACCOUNT_TYPE"
    log "ERROR" "Please ensure you are properly authenticated with Azure CLI"
    exit 1
  fi
  
  log "INFO" "Current user/principal object ID: $USER_OBJECT_ID"
  
  # Assign Key Vault Secrets Officer role to current user
  log "INFO" "Assigning Key Vault Secrets Officer role to current user..."
  if ! az role assignment create \
    --role "Key Vault Secrets Officer" \
    --assignee "$USER_OBJECT_ID" \
    --scope "/subscriptions/$(az account show --query id -o tsv)/resourcegroups/$LANDING_ZONE_RESOURCE_GROUP/providers/microsoft.keyvault/vaults/$BOOTSTRAP_KV_NAME" \
    >/dev/null 2>&1; then
    log "WARNING" "Failed to assign RBAC role, trying legacy access policy approach..."
    
    # Fallback to access policy approach
    if ! az keyvault set-policy \
      --name "$BOOTSTRAP_KV_NAME" \
      --object-id "$USER_OBJECT_ID" \
      --secret-permissions get list set delete backup restore recover purge \
      >/dev/null 2>&1; then
      log "ERROR" "Failed to set Key Vault permissions using both RBAC and access policies"
      log "ERROR" "Please manually assign Key Vault Secrets Officer role or set access policies"
      exit 1
    else
      log "INFO" "✅ Key Vault permissions set using access policy"
    fi
  else
    log "INFO" "✅ Key Vault Secrets Officer role assigned successfully"
  fi
  
  # Wait for permission propagation
  log "INFO" "Waiting 30 seconds for permissions to propagate..."
  sleep 30
  
  # =====================
  # 2.2. Seed Bootstrap Key Vault with Encryption Keys
  # =====================
  if [[ "$SKIP_KEY_SEEDING" == false ]]; then
    log "INFO" "Seeding Bootstrap Key Vault with Fernet encryption keys..."
    log "INFO" "This is a critical security step that generates the master encryption keys..."
    
    # Generate Fernet encryption key using OpenSSL
    log "INFO" "Generating cryptographically secure Fernet encryption key..."
    
    # Generate 32 random bytes and base64 encode (Fernet key format)
    if command -v openssl >/dev/null 2>&1; then
      ENCRYPTION_KEY=$(openssl rand -base64 32)
      log "INFO" "Encryption key generated using OpenSSL"
    else
      # Fallback to /dev/urandom if OpenSSL is not available
      if [[ -r /dev/urandom ]]; then
        ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
        log "INFO" "Encryption key generated using /dev/urandom"
      else
        log "ERROR" "Neither OpenSSL nor /dev/urandom available for key generation"
        log "ERROR" "Please install OpenSSL or ensure /dev/urandom is accessible"
        exit 1
      fi
    fi
    
    # Remove any whitespace/newlines from the key
    ENCRYPTION_KEY=$(echo "$ENCRYPTION_KEY" | tr -d '\n\r ')
    
    # Validate key length (Fernet keys should be 44 characters when base64 encoded)
    KEY_LENGTH=${#ENCRYPTION_KEY}
    if [[ $KEY_LENGTH -ne 44 ]]; then
      log "ERROR" "Generated key has incorrect length: $KEY_LENGTH (expected 44)"
      log "ERROR" "This indicates an issue with key generation"
      exit 1
    fi
    
    log "INFO" "Generated valid Fernet encryption key (length: $KEY_LENGTH chars)"
    log "INFO" "Key preview (first 8 chars): ${ENCRYPTION_KEY:0:8}..."
    
    # Check if encryption key already exists in Key Vault
    log "INFO" "Checking if encryption key already exists in Key Vault..."
    if az keyvault secret show --vault-name "$BOOTSTRAP_KV_NAME" --name "encryption-key" >/dev/null 2>&1; then
      log "WARNING" "Encryption key already exists in Key Vault: $BOOTSTRAP_KV_NAME"
      log "WARNING" "Skipping key generation to prevent overwriting existing key"
      log "WARNING" "Use --skip-key-seeding to skip this step, or manually delete the key to regenerate"
    else
      # Set encryption key in Key Vault with metadata tags
      log "INFO" "Storing encryption key in Key Vault..."
      CURRENT_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
      
      if ! az keyvault secret set \
        --vault-name "$BOOTSTRAP_KV_NAME" \
        --name "encryption-key" \
        --value "$ENCRYPTION_KEY" \
        --tags \
          purpose="primary-encryption" \
          generated="$CURRENT_TIME" \
          generator="bootstrap-deployment" \
          rotation-supported="true" \
        >/dev/null; then
        log "ERROR" "Failed to store encryption key in Key Vault"
        log "ERROR" "Ensure you have Key Vault Secret Officer permissions"
        exit 1
      fi
      
      log "INFO" "✅ Encryption key stored successfully in Key Vault"
      log "INFO" "✅ Bootstrap Key Vault seeded successfully with encryption keys"
    fi
  else
    log "INFO" "Skipping Key Vault seeding (--skip-key-seeding flag provided)"
    log "WARNING" "Ensure encryption keys are already present in the Key Vault!"
  fi
else
  log "INFO" "Skipping Bootstrap Key Vault deployment"
  
  # If skipping bootstrap, we still need the Key Vault name for later steps
  # Try to get it from an existing deployment
  log "INFO" "Attempting to retrieve existing Bootstrap Key Vault name..."
  BOOTSTRAP_KV_NAME=$(az deployment group show \
    --name "$BOOTSTRAP_KV_DEPLOYMENT_NAME" \
    --resource-group "$LANDING_ZONE_RESOURCE_GROUP" \
    --query properties.outputs.keyVaultName.value -o tsv 2>/dev/null || echo "")
  
  if [[ -z "$BOOTSTRAP_KV_NAME" || "$BOOTSTRAP_KV_NAME" == "null" ]]; then
    log "WARNING" "Could not retrieve Bootstrap Key Vault name from existing deployment"
    log "WARNING" "Platform deployment may fail if it requires Key Vault references"
    # Set a default based on naming convention from the bicep file
    BOOTSTRAP_KV_NAME="ssdakskv"
    log "INFO" "Using default Key Vault name: $BOOTSTRAP_KV_NAME"
  else
    log "INFO" "Retrieved existing Bootstrap Key Vault name: $BOOTSTRAP_KV_NAME"
  fi
  
  # Validate that the Key Vault exists and is accessible
  if ! az keyvault show --name "$BOOTSTRAP_KV_NAME" >/dev/null 2>&1; then
    log "ERROR" "Bootstrap Key Vault '$BOOTSTRAP_KV_NAME' does not exist or is not accessible"
    log "ERROR" "Ensure the Bootstrap Key Vault exists or run without --skip-bootstrap-kv flag"
    exit 1
  fi
fi
# =====================
# 3. Deploy Platform Infrastructure (AKS) 
# =====================
if [[ "$SKIP_INFRA" == false ]]; then
  log "INFO" "Deploying AKS Platform infrastructure (AKS cluster, Application Gateway, networking, etc.)..."
  log "INFO" "This may take 10-15 minutes..."
  log "INFO" "Target resource group: $LANDING_ZONE_RESOURCE_GROUP"
  
  if ! az deployment group create \
    --template-file "$PLATFORM_BICEP_FILE" \
    --parameters "$PLATFORM_PARAMS_FILE" \
    --resource-group "$LANDING_ZONE_RESOURCE_GROUP" \
    --name "$PLATFORM_DEPLOYMENT_NAME" \
    --no-prompt \
    --verbose; then
    log "ERROR" "AKS Platform infrastructure deployment failed"
    get_deployment_errors "$PLATFORM_DEPLOYMENT_NAME" "$LANDING_ZONE_RESOURCE_GROUP"
    exit 1
  fi
  log "INFO" "AKS Platform infrastructure deployment completed"
else
  log "INFO" "Skipping AKS Platform infrastructure deployment"
fi

# =====================
# 4. Retrieve Platform Infrastructure Outputs
# =====================
log "INFO" "Retrieving outputs from Platform infrastructure deployment..."

# First, check if we can retrieve the resource group from platform deployment
RESOURCE_GROUP=$(az deployment group show --name "$PLATFORM_DEPLOYMENT_NAME" --resource-group "$LANDING_ZONE_RESOURCE_GROUP" --query properties.outputs.resourceGroupName.value -o tsv 2>/dev/null || echo "")

# Handle case where platform infrastructure deployment was skipped or failed
if [[ -z "$RESOURCE_GROUP" || "$RESOURCE_GROUP" == "null" ]]; then
  log "WARNING" "Could not retrieve resource group from platform deployment outputs (likely because platform deployment was skipped)"
  log "INFO" "Using landing zone resource group as fallback: $LANDING_ZONE_RESOURCE_GROUP"
  RESOURCE_GROUP="$LANDING_ZONE_RESOURCE_GROUP"
fi

log "DEBUG" "Raw RESOURCE_GROUP value: '$RESOURCE_GROUP'"
log "INFO" "RESOURCE_GROUP=$RESOURCE_GROUP"

# Now retrieve other outputs (these may be empty if platform deployment was skipped)
AKS_NAME=$(az deployment group show --name "$PLATFORM_DEPLOYMENT_NAME" --resource-group "$LANDING_ZONE_RESOURCE_GROUP" --query properties.outputs.aksName.value -o tsv 2>/dev/null || echo "")
ACR_LOGIN_SERVER=$(az deployment group show --name "$PLATFORM_DEPLOYMENT_NAME" --resource-group "$LANDING_ZONE_RESOURCE_GROUP" --query properties.outputs.acrLoginServer.value -o tsv 2>/dev/null || echo "")
APP_GW_IP=$(az deployment group show --name "$PLATFORM_DEPLOYMENT_NAME" --resource-group "$LANDING_ZONE_RESOURCE_GROUP" --query properties.outputs.appGwPublicIp.value -o tsv 2>/dev/null || echo "")
TENANT_ID=$(az deployment group show --name "$PLATFORM_DEPLOYMENT_NAME" --resource-group "$LANDING_ZONE_RESOURCE_GROUP" --query properties.outputs.tenantId.value -o tsv 2>/dev/null || echo "")
BACKEND_UAMI_CLIENT_ID=$(az deployment group show --name "$PLATFORM_DEPLOYMENT_NAME" --resource-group "$LANDING_ZONE_RESOURCE_GROUP" --query properties.outputs.backendUamiClientId.value -o tsv 2>/dev/null || echo "")
BACKEND_SERVICE_ACCOUNT_NAME=$(az deployment group show --name "$PLATFORM_DEPLOYMENT_NAME" --resource-group "$LANDING_ZONE_RESOURCE_GROUP" --query properties.outputs.backendK8sServiceAccountName.value -o tsv 2>/dev/null || echo "")
COSMOS_DATABASE_NAME=$(az deployment group show --name "$PLATFORM_DEPLOYMENT_NAME" --resource-group "$LANDING_ZONE_RESOURCE_GROUP" --query properties.outputs.cosmosDatabaseName.value -o tsv 2>/dev/null || echo "")
COSMOS_CONTAINER_NAME=$(az deployment group show --name "$PLATFORM_DEPLOYMENT_NAME" --resource-group "$LANDING_ZONE_RESOURCE_GROUP" --query properties.outputs.cosmosContainerName.value -o tsv 2>/dev/null || echo "")
COSMOS_DB_ACCOUNT_NAME=$(az deployment group show --name "$PLATFORM_DEPLOYMENT_NAME" --resource-group "$LANDING_ZONE_RESOURCE_GROUP" --query properties.outputs.cosmosDbAccountName.value -o tsv 2>/dev/null || echo "")
COSMOS_DB_ENDPOINT="https://${COSMOS_DB_ACCOUNT_NAME}.documents.azure.com:443/"

log "INFO" "Successfully retrieved Platform infrastructure outputs:"
log "INFO" "AKS_NAME=$AKS_NAME"
log "INFO" "RESOURCE_GROUP=$RESOURCE_GROUP"
log "INFO" "ACR_LOGIN_SERVER=$ACR_LOGIN_SERVER"
log "INFO" "APP_GW_IP=$APP_GW_IP"
log "INFO" "TENANT_ID=$TENANT_ID"
log "INFO" "BACKEND_UAMI_CLIENT_ID=$BACKEND_UAMI_CLIENT_ID"
log "INFO" "BACKEND_SERVICE_ACCOUNT_NAME=$BACKEND_SERVICE_ACCOUNT_NAME"
log "INFO" "COSMOS_DATABASE_NAME=$COSMOS_DATABASE_NAME"
log "INFO" "COSMOS_CONTAINER_NAME=$COSMOS_CONTAINER_NAME"
log "INFO" "COSMOS_DB_ACCOUNT_NAME=$COSMOS_DB_ACCOUNT_NAME"
log "INFO" "COSMOS_DB_ENDPOINT=$COSMOS_DB_ENDPOINT"

# Validate critical outputs before proceeding
if [[ -z "$AKS_NAME" || "$AKS_NAME" == "null" ]]; then
  log "ERROR" "AKS cluster name is missing from platform deployment outputs"
  log "ERROR" "This indicates the platform deployment may have failed or the AKS cluster was not created"
  log "ERROR" "Attempting to find AKS cluster directly in the resource group..."
  
  # Try to find the AKS cluster directly
  AKS_NAME=$(az aks list --resource-group "$LANDING_ZONE_RESOURCE_GROUP" --query '[0].name' -o tsv 2>/dev/null || echo "")
  
  if [[ -n "$AKS_NAME" && "$AKS_NAME" != "null" ]]; then
    log "INFO" "Found AKS cluster directly: $AKS_NAME"
  else
    log "ERROR" "Could not find AKS cluster in resource group: $LANDING_ZONE_RESOURCE_GROUP"
    log "ERROR" "Please check the platform deployment status and logs"
    exit 1
  fi
fi

if [[ -z "$ACR_LOGIN_SERVER" || "$ACR_LOGIN_SERVER" == "null" ]]; then
  log "ERROR" "Azure Container Registry login server is missing from platform deployment outputs"
  log "ERROR" "Attempting to find ACR directly in the resource group..."
  
  # Try to find the ACR directly
  ACR_LOGIN_SERVER=$(az acr list --resource-group "$LANDING_ZONE_RESOURCE_GROUP" --query '[0].loginServer' -o tsv 2>/dev/null || echo "")
  
  if [[ -n "$ACR_LOGIN_SERVER" && "$ACR_LOGIN_SERVER" != "null" ]]; then
    log "INFO" "Found Azure Container Registry directly: $ACR_LOGIN_SERVER"
  else
    log "ERROR" "Could not find Azure Container Registry in resource group: $LANDING_ZONE_RESOURCE_GROUP"
    exit 1
  fi
fi

if [[ -z "$COSMOS_DB_ENDPOINT" || "$COSMOS_DB_ENDPOINT" == "null" ]]; then
  log "ERROR" "Cosmos DB endpoint is missing from platform deployment outputs"
  log "ERROR" "Attempting to find Cosmos DB directly in the resource group..."
  
  # Try to find the Cosmos DB directly
  COSMOS_DB_ENDPOINT=$(az cosmosdb list --resource-group "$LANDING_ZONE_RESOURCE_GROUP" --query '[0].documentEndpoint' -o tsv 2>/dev/null || echo "")
  
  if [[ -n "$COSMOS_DB_ENDPOINT" && "$COSMOS_DB_ENDPOINT" != "null" ]]; then
    log "INFO" "Found Cosmos DB directly: $COSMOS_DB_ENDPOINT"
    
    # Validate that database and container names are available from platform deployment outputs
    if [[ -z "$COSMOS_DATABASE_NAME" || "$COSMOS_DATABASE_NAME" == "null" ]]; then
      log "ERROR" "Cosmos DB database name is missing from platform deployment outputs"
      log "ERROR" "The platform deployment may have failed or the cosmosDatabaseName output is not defined"
      exit 1
    fi
    if [[ -z "$COSMOS_CONTAINER_NAME" || "$COSMOS_CONTAINER_NAME" == "null" ]]; then
      log "ERROR" "Cosmos DB container name is missing from platform deployment outputs"
      log "ERROR" "The platform deployment may have failed or the cosmosContainerName output is not defined"
      exit 1
    fi
  else
    log "ERROR" "Could not find Cosmos DB in resource group: $LANDING_ZONE_RESOURCE_GROUP"
    exit 1
  fi
fi

log "INFO" "✅ All critical platform outputs validated successfully"

# =====================
# 5. Build & Push Container Images
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
    docker build -t "$IMAGE" "../src/$svc" --progress=plain
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
# 6. Connect to AKS and Deploy Workload
# =====================
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

# =====================
# 7. Deploy Helm Chart
# =====================
log "INFO" "Deploying Helm chart (this may take a few minutes)..."

# Parse image references from IMAGES array
BACKEND_TAG=""
FRONTEND_TAG=""

for image_entry in "${IMAGES[@]}"; do
  svc="${image_entry%%:*}"
  image="${image_entry#*:}"
  repo="${image%:*}"
  tag="${image##*:}"
  
  if [[ "$svc" == "backend" ]]; then
    BACKEND_TAG="$tag"
  elif [[ "$svc" == "frontend" ]]; then
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
log "INFO" "- AZURE_KEY_VAULT_URL: https://$BOOTSTRAP_KV_NAME.vault.azure.net/"
log "INFO" "- USE_MANAGED_IDENTITY: true"
log "INFO" "- FLASK_APP: app/main.py"
log "INFO" "- FLASK_ENV: production"
log "INFO" "- AZURE_LOG_LEVEL: INFO"
log "INFO" "- PYTHONUNBUFFERED: 1"
log "INFO" "=============================================="
log "INFO" "COPY-PASTE COMMAND (with actual values):"
echo "helm upgrade --install secret-sharer ../deploy/helm \\"
echo "  --namespace default --create-namespace \\"
echo "  --set backend.serviceAccount.name=\"$BACKEND_SERVICE_ACCOUNT_NAME\" \\"
echo "  --set backend.image.tag=\"$BACKEND_TAG\" \\"
echo "  --set frontend.image.tag=\"$FRONTEND_TAG\" \\"
echo "  --set acrLoginServer=\"$ACR_LOGIN_SERVER\" \\"
echo "  --set cosmosdb.endpoint=\"$COSMOS_DB_ENDPOINT\" \\"
echo "  --set cosmosdb.databaseName=\"$COSMOS_DATABASE_NAME\" \\"
echo "  --set cosmosdb.containerName=\"$COSMOS_CONTAINER_NAME\" \\"
echo "  --set backend.env.AZURE_CLIENT_ID=\"$BACKEND_UAMI_CLIENT_ID\" \\"
echo "  --set backend.env.AZURE_TENANT_ID=\"$TENANT_ID\" \\"
echo "  --set backend.env.AZURE_KEY_VAULT_URL=\"https://$BOOTSTRAP_KV_NAME.vault.azure.net/\" \\"
echo "  --set backend.keyVault.name=\"$BOOTSTRAP_KV_NAME\" \\"
echo "  --set backend.keyVault.tenantId=\"$TENANT_ID\" \\"
echo "  --set backend.keyVault.userAssignedIdentityClientID=\"$BACKEND_UAMI_CLIENT_ID\" \\"
echo "  --timeout=15m \\"
echo "  --wait \\"
echo "  --debug"
log "INFO" "=============================================="
helm upgrade --install secret-sharer ../deploy/helm \
  --namespace default --create-namespace \
  --set backend.serviceAccount.name="$BACKEND_SERVICE_ACCOUNT_NAME" \
  --set backend.image.tag="$BACKEND_TAG" \
  --set frontend.image.tag="$FRONTEND_TAG" \
  --set acrLoginServer="$ACR_LOGIN_SERVER" \
  --set cosmosdb.endpoint="$COSMOS_DB_ENDPOINT" \
  --set cosmosdb.databaseName="$COSMOS_DATABASE_NAME" \
  --set cosmosdb.containerName="$COSMOS_CONTAINER_NAME" \
  --set backend.env.AZURE_CLIENT_ID="$BACKEND_UAMI_CLIENT_ID" \
  --set backend.env.AZURE_TENANT_ID="$TENANT_ID" \
  --set backend.env.AZURE_KEY_VAULT_URL="https://$BOOTSTRAP_KV_NAME.vault.azure.net/" \
  --set backend.keyVault.name="$BOOTSTRAP_KV_NAME" \
  --set backend.keyVault.tenantId="$TENANT_ID" \
  --set backend.keyVault.userAssignedIdentityClientID="$BACKEND_UAMI_CLIENT_ID" \
  --timeout=15m \
  --wait \
  --debug || {
  log "ERROR" "Helm deployment failed"
  log "INFO" "Retrieving Helm deployment status..."
  helm status secret-sharer --namespace default || true
  log "INFO" "Retrieving pod logs for debugging..."
  kubectl get pods --namespace default || true
  kubectl describe pods --namespace default || true
  exit 1
}

log "INFO" "✅ Helm deployment completed successfully"

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

# =====================
# 8) Summary
# =====================
echo ""
echo "=============================================="
echo "DEPLOYMENT SUMMARY"
echo "=============================================="
echo "Application URL: http://$HOSTNAME"
echo "AKS Cluster: $AKS_NAME"
echo "Resource Group: $RESOURCE_GROUP"
echo "Container Registry: $ACR_LOGIN_SERVER"
echo "Bootstrap Key Vault: $BOOTSTRAP_KV_NAME"
echo "Tenant ID: $TENANT_ID"
echo "Backend Identity: $BACKEND_UAMI_CLIENT_ID"
echo ""
echo "Infrastructure Details:"
echo "Cosmos DB Endpoint: $COSMOS_DB_ENDPOINT"
echo "Database Name: $COSMOS_DATABASE_NAME"
echo "Container Name: $COSMOS_CONTAINER_NAME"
echo "Key Vault URL: https://$BOOTSTRAP_KV_NAME.vault.azure.net/"
echo ""
echo "Deployment Sequence Completed:"
echo "✅ 1. Landing Zone (shared infrastructure)"
echo "✅ 2. Bootstrap Key Vault (encryption key management)"
echo "✅ 3. Platform Infrastructure (AKS cluster, Application Gateway, networking, etc.)"
echo "✅ 4. Container Images (built and pushed to ACR)"
echo "✅ 5. Workload Applications (Helm chart deployed to AKS)"
echo ""
echo "🎉 Deployment Complete!"
echo "✅ Backend and frontend are deployed to AKS"
echo "✅ Application is accessible via Application Gateway"
echo "✅ Encryption keys are securely managed in Azure Key Vault"
echo "=============================================="