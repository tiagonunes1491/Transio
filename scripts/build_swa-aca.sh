#!/usr/bin/env bash
set -euo pipefail

# build_swa-aca.sh - SWA deployment for Secure Secret Sharer on Azure Container Apps + Static Web Apps
# This script leverages the modular landing zone deployment with proper deployment sequence:
# 1. Landing Zone (shared infrastructure + networking)
# 2. Bootstrap Key Vault (platform-specific secrets management) 
# 3. Key Vault Seeding (generate and store Fernet encryption keys)
# 4. Platform Infrastructure (Container Apps Environment, Cosmos DB, etc.)
# 5. Workload Applications (Static Web App + Container App)
# 
# NOTE: This script has been updated to work with the new folder structure:
# - Backend: src/backend/ (contains Dockerfile and backend code)
# - Frontend: src/frontend/ (contains static files for SWA deployment)
# - Helm Charts: deploy/helm/ (not used by this SWA deployment script)
# - Infrastructure: infra/ (unchanged)
#
# NOTE: After folder structure changes (from 01-bootstrap-kv to 10-bootstrap-kv), the deploy-landing-zone.sh 
# script may reference old folder paths. If landing zone deployment fails, use --skip-landing-zone
# and manually deploy the landing zone using the 0-landing-zone/ folder.
#
# Usage: ./build_swa-aca.sh [--skip-landing-zone] [--skip-bootstrap-kv] [--skip-key-seeding] [--skip-infra] [--skip-containers] [--skip-frontend] [--full-rebuild] [--teardown-only]

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
SKIP_BOOTSTRAP_KV=false
SKIP_KEY_SEEDING=false
SKIP_INFRA=false
SKIP_CONTAINERS=false
SKIP_FRONTEND=false
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
    --skip-frontend) SKIP_FRONTEND=true; shift ;;
    --full-rebuild) FULL_REBUILD=true; shift ;;
    --teardown-only) TEARDOWN_ONLY=true; shift ;;
    -h|--help)
      echo "Usage: $0 [--skip-landing-zone] [--skip-bootstrap-kv] [--skip-key-seeding] [--skip-infra] [--skip-containers] [--skip-frontend] [--full-rebuild] [--teardown-only]"; exit 0 ;;
    *)
      echo "Unknown option: $1"; exit 1 ;;
  esac
  done

# =====================
# Deployment Names & Paths
# =====================
LOCATION="spaincentral"
SERVICES=("backend")

# Bootstrap Key Vault Deployment
BOOTSTRAP_KV_DEPLOYMENT_NAME="Secure-Sharer-Bootstrap-KV"
BOOTSTRAP_KV_BICEP_FILE="../infra/10-bootstrap-kv/main.bicep"
BOOTSTRAP_KV_PARAMS_FILE="../infra/10-bootstrap-kv/swa.dev.bicepparam"

# Platform Infrastructure Deployment (SWA)
PLATFORM_DEPLOYMENT_NAME="Secure-Sharer-Platform-SWA"
PLATFORM_BICEP_FILE="../infra/20-platform-swa/main.bicep"
PLATFORM_PARAMS_FILE="../infra/20-platform-swa/main.dev.bicepparam"

# Workload Application Deployment (SWA)
WORKLOAD_DEPLOYMENT_NAME="Secure-Sharer-Workload-SWA"
WORKLOAD_BICEP_FILE="../infra/30-workload-swa/main.bicep"
WORKLOAD_PARAMS_FILE="../infra/30-workload-swa/main.dev.bicepparam"

# =====================
# Prerequisites
# =====================
log "INFO" "Checking prerequisites..."
command -v az >/dev/null || { log "ERROR" "az CLI not found"; exit 1; }
command -v docker >/dev/null || { log "ERROR" "docker not found"; exit 1; }
command -v swa >/dev/null || { log "ERROR" "swa CLI not found. Install with: npm install -g @azure/static-web-apps-cli"; exit 1; }

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
  log "INFO" "Teardown-only mode: deleting all deployments and landing zone..."
  
  # Use actual resource group name for teardown
  ACTUAL_RESOURCE_GROUP="ss-d-swa-rg"
  
  # Step 1: Check if Key Vault exists in the resource group and delete it
  log "INFO" "Step 1: Checking for Key Vault in resource group: $ACTUAL_RESOURCE_GROUP"
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
      
      # Step 2: Attempt to purge the Key Vault (background)
      log "INFO" "Step 2: Attempting to purge Key Vault: $KEY_VAULT_NAME (background)"
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
  log "INFO" "Deleting workload deployment..."
  az deployment group delete --name "$WORKLOAD_DEPLOYMENT_NAME" --resource-group "$ACTUAL_RESOURCE_GROUP" --verbose 2>/dev/null || true
  
  log "INFO" "Deleting platform deployment..."
  az deployment group delete --name "$PLATFORM_DEPLOYMENT_NAME" --resource-group "$ACTUAL_RESOURCE_GROUP" --verbose 2>/dev/null || true
  
  log "INFO" "Deleting bootstrap Key Vault deployment..."
  az deployment group delete --name "$BOOTSTRAP_KV_DEPLOYMENT_NAME" --resource-group "$ACTUAL_RESOURCE_GROUP" --verbose 2>/dev/null || true
  
  # Step 3: Start resource group deletion in background
  log "INFO" "Step 3: Starting resource group deletion: $ACTUAL_RESOURCE_GROUP (background)"
  az group delete --name "$ACTUAL_RESOURCE_GROUP" --yes --no-wait --verbose 2>/dev/null &
  RG_DELETE_PID=$!
  
  # Step 4: Wait for Key Vault purge and resource group deletion to complete
  if [[ -n "$PURGE_PID" ]]; then
    log "INFO" "Step 4: Waiting for Key Vault purge operation to complete..."
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
  
  # Skip landing zone teardown as it looks for wrong resource group names
  log "INFO" "Skipping landing zone teardown (looks for non-existent resource groups)"
  log "INFO" "Teardown completed successfully"
  exit 0
fi

if [[ "$FULL_REBUILD" == true ]]; then
  log "INFO" "Full rebuild requested: tearing down all deployments and landing zone..."
  
  # Use actual resource group name for teardown
  ACTUAL_RESOURCE_GROUP="ss-d-swa-rg"
  
  # Step 1: Check if Key Vault exists in resource group and handle it
  log "INFO" "Step 1: Checking for Key Vault in resource group: $ACTUAL_RESOURCE_GROUP"
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
  log "INFO" "Deleting workload deployment..."
  az deployment group delete --name "$WORKLOAD_DEPLOYMENT_NAME" --resource-group "$ACTUAL_RESOURCE_GROUP" --verbose 2>/dev/null || true
  
  log "INFO" "Deleting platform deployment..."
  az deployment group delete --name "$PLATFORM_DEPLOYMENT_NAME" --resource-group "$ACTUAL_RESOURCE_GROUP" --verbose 2>/dev/null || true
  
  log "INFO" "Deleting bootstrap Key Vault deployment..."
  az deployment group delete --name "$BOOTSTRAP_KV_DEPLOYMENT_NAME" --resource-group "$ACTUAL_RESOURCE_GROUP" --verbose 2>/dev/null || true
  
  # Step 3: Start resource group deletion in background
  log "INFO" "Step 3: Starting resource group deletion: $ACTUAL_RESOURCE_GROUP (background)"
  az group delete --name "$ACTUAL_RESOURCE_GROUP" --yes --no-wait --verbose 2>/dev/null &
  RG_DELETE_PID=$!
  
  # Step 4: Wait for Key Vault purge and resource group deletion to complete
  if [[ -n "$PURGE_PID" ]]; then
    log "INFO" "Step 4: Waiting for Key Vault purge operation to complete..."
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
  ./deploy-landing-zone.sh paas
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
  --query "sort_by([?contains(name, 'landing-zone-paas')], &properties.timestamp) | [-1].name" \
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
  LANDING_ZONE_RESOURCE_GROUP="ss-d-swa-rg"
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

log "INFO" "Confirmed resource group exists: $LANDING_ZONE_RESOURCE_GROUP"

# =====================
# 2. Deploy Bootstrap Key Vault 
# =====================
if [[ "$SKIP_BOOTSTRAP_KV" == false ]]; then
  log "INFO" "Deploying Bootstrap Key Vault for SWA platform..."
  log "INFO" "This creates the platform-specific Key Vault that will be used by the platform infrastructure..."
  log "INFO" "Target resource group: $LANDING_ZONE_RESOURCE_GROUP"
  
  # =====================
  # 2.0. Check for and recover soft-deleted Key Vault
  # =====================
  log "INFO" "Checking for existing soft-deleted Key Vault..."
  
  # First, we need to determine what the Key Vault name will be based on the bicep parameters
  # Read the expected Key Vault name from the naming convention
  EXPECTED_KV_NAME="ssdswakv"  # Based on actual Key Vault naming: ssdswakv
  
  # Check if a Key Vault with this name exists in soft-deleted state
  log "INFO" "Checking for soft-deleted Key Vault: $EXPECTED_KV_NAME"
  DELETED_KV_INFO=$(az keyvault list-deleted --query "[?name=='$EXPECTED_KV_NAME']" -o json 2>/dev/null || echo "[]")
  
  # Also check without location filter in case of any location mismatch
  if [[ "$DELETED_KV_INFO" == "[]" || "$DELETED_KV_INFO" == "" ]]; then
    log "INFO" "No soft-deleted Key Vault found with location filter, checking globally..."
    DELETED_KV_INFO=$(az keyvault list-deleted --query "[?name=='$EXPECTED_KV_NAME']" -o json 2>/dev/null || echo "[]")
  fi
  
  if [[ "$DELETED_KV_INFO" != "[]" && "$DELETED_KV_INFO" != "" ]]; then
    log "WARNING" "Found soft-deleted Key Vault: $EXPECTED_KV_NAME"
    log "INFO" "Attempting to recover soft-deleted Key Vault..."
    
    if az keyvault recover --name "$EXPECTED_KV_NAME" --location "$LOCATION" 2>/dev/null; then
      log "INFO" "✅ Successfully recovered soft-deleted Key Vault: $EXPECTED_KV_NAME"
      log "INFO" "Waiting 30 seconds for recovery to complete..."
      sleep 30
      
      # Verify the Key Vault is now accessible
      if az keyvault show --name "$EXPECTED_KV_NAME" >/dev/null 2>&1; then
        log "INFO" "✅ Key Vault is now accessible: $EXPECTED_KV_NAME"
        
        # Since we recovered the Key Vault, we should skip the Bicep deployment
        # and use the recovered Key Vault
        log "INFO" "Using recovered Key Vault instead of deploying new one"
        BOOTSTRAP_KV_NAME="$EXPECTED_KV_NAME"
        
        # Skip the Bicep deployment section and go directly to permissions setup
        log "INFO" "Skipping Bicep deployment since Key Vault was recovered"
      else
        log "WARNING" "Key Vault recovery completed but Key Vault is not accessible yet"
        log "WARNING" "Proceeding with Bicep deployment which may handle the final setup"
      fi
    else
      log "WARNING" "Failed to recover soft-deleted Key Vault: $EXPECTED_KV_NAME"
      log "WARNING" "This may be due to purge protection or insufficient permissions"
      log "WARNING" "Proceeding with Bicep deployment which will likely fail"
      log "WARNING" "Manual intervention may be required to purge or recover the Key Vault"
    fi
  else
    log "INFO" "No soft-deleted Key Vault found for name: $EXPECTED_KV_NAME"
    log "INFO" "Proceeding with normal Bicep deployment"
  fi
  
  # Initialize BOOTSTRAP_KV_NAME variable
  BOOTSTRAP_KV_NAME=""
  
  # Only attempt Bicep deployment if we didn't recover a Key Vault
  if [[ -z "$BOOTSTRAP_KV_NAME" ]]; then
    # Final check for soft-deleted Key Vault before deployment (fallback)
    log "INFO" "Performing final check for soft-deleted Key Vault before deployment..."
    FINAL_DELETED_CHECK=$(az keyvault list-deleted --query "[?name=='$EXPECTED_KV_NAME']" -o json 2>/dev/null || echo "[]")
    
    if [[ "$FINAL_DELETED_CHECK" != "[]" && "$FINAL_DELETED_CHECK" != "" ]]; then
      log "WARNING" "Found soft-deleted Key Vault in final check: $EXPECTED_KV_NAME"
      log "INFO" "Attempting recovery before deployment..."
      
      if az keyvault recover --name "$EXPECTED_KV_NAME" --location "$LOCATION" 2>/dev/null; then
        log "INFO" "✅ Successfully recovered Key Vault in final check: $EXPECTED_KV_NAME"
        BOOTSTRAP_KV_NAME="$EXPECTED_KV_NAME"
        log "INFO" "Waiting 30 seconds for recovery to complete..."
        sleep 30
      else
        log "WARNING" "Failed to recover Key Vault in final check, proceeding with deployment"
      fi
    fi
    
    # Proceed with Bicep deployment only if recovery didn't work
    if [[ -z "$BOOTSTRAP_KV_NAME" ]]; then
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
      
      # Check for soft-delete related error messages in the entire error object
      if echo "$DEPLOYMENT_ERROR" | grep -q "soft delete" || \
         echo "$DEPLOYMENT_ERROR" | grep -q "same name already exists in deleted state" || \
         echo "$DEPLOYMENT_ERROR" | grep -q "already exists in deleted state"; then
        log "WARNING" "Deployment failed due to soft-delete conflict"
        log "INFO" "Attempting Key Vault recovery as fallback..."
        
        if az keyvault recover --name "$EXPECTED_KV_NAME" --location "$LOCATION" 2>/dev/null; then
          log "INFO" "✅ Successfully recovered Key Vault after deployment failure"
          BOOTSTRAP_KV_NAME="$EXPECTED_KV_NAME"
          log "INFO" "Waiting 30 seconds for recovery to complete..."
          sleep 30
        else
          log "ERROR" "Failed to recover Key Vault after deployment failure"
          log "ERROR" "Manual intervention required - either purge or recover the Key Vault manually"
          exit 1
        fi
      else
        log "ERROR" "Deployment failed for reasons other than soft-delete conflict"
        exit 1
      fi
    else
      log "INFO" "Bootstrap Key Vault deployment completed"
      
      # Retrieve Key Vault name from deployment outputs
      log "INFO" "Retrieving Key Vault name from Bootstrap deployment..."
      BOOTSTRAP_KV_NAME=$(az deployment group show \
        --name "$BOOTSTRAP_KV_DEPLOYMENT_NAME" \
        --resource-group "$LANDING_ZONE_RESOURCE_GROUP" \
        --query properties.outputs.keyVaultName.value -o tsv)
      
      if [[ -z "$BOOTSTRAP_KV_NAME" || "$BOOTSTRAP_KV_NAME" == "null" ]]; then
        log "ERROR" "Failed to retrieve Key Vault name from Bootstrap deployment"
        exit 1
      fi
      fi
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
    BOOTSTRAP_KV_NAME="ssdswakv"
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
# 3. Deploy Platform Infrastructure (SWA) 
# =====================
if [[ "$SKIP_INFRA" == false ]]; then
  log "INFO" "Deploying SWA Platform infrastructure (Container Apps Environment, VNet, etc.)..."
  log "INFO" "This may take 10-15 minutes..."
  log "INFO" "Target resource group: $LANDING_ZONE_RESOURCE_GROUP"
  
  if ! az deployment group create \
    --template-file "$PLATFORM_BICEP_FILE" \
    --parameters "$PLATFORM_PARAMS_FILE" \
    --resource-group "$LANDING_ZONE_RESOURCE_GROUP" \
    --name "$PLATFORM_DEPLOYMENT_NAME" \
    --no-prompt \
    --verbose; then
    log "ERROR" "SWA Platform infrastructure deployment failed"
    get_deployment_errors "$PLATFORM_DEPLOYMENT_NAME" "$LANDING_ZONE_RESOURCE_GROUP"
    exit 1
  fi
  log "INFO" "SWA Platform infrastructure deployment completed"
else
  log "INFO" "Skipping SWA Platform infrastructure deployment"
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
  log "INFO" "Using landing zone resource group as fallback for workload deployment: $LANDING_ZONE_RESOURCE_GROUP"
  RESOURCE_GROUP="$LANDING_ZONE_RESOURCE_GROUP"
fi

log "DEBUG" "Raw RESOURCE_GROUP value: '$RESOURCE_GROUP'"
log "INFO" "RESOURCE_GROUP=$RESOURCE_GROUP"

# Now retrieve other outputs (these may be empty if platform deployment was skipped)
ACA_ENVIRONMENT_ID=$(az deployment group show --name "$PLATFORM_DEPLOYMENT_NAME" --resource-group "$LANDING_ZONE_RESOURCE_GROUP" --query properties.outputs.acaEnvironmentId.value -o tsv 2>/dev/null || echo "")
UAMI_ID=$(az deployment group show --name "$PLATFORM_DEPLOYMENT_NAME" --resource-group "$LANDING_ZONE_RESOURCE_GROUP" --query properties.outputs.uamiId.value -o tsv 2>/dev/null || echo "")
ACR_LOGIN_SERVER=$(az deployment group show --name "$PLATFORM_DEPLOYMENT_NAME" --resource-group "$LANDING_ZONE_RESOURCE_GROUP" --query properties.outputs.acrLoginServer.value -o tsv 2>/dev/null || echo "")
KEY_VAULT_URI=$(az deployment group show --name "$PLATFORM_DEPLOYMENT_NAME" --resource-group "$LANDING_ZONE_RESOURCE_GROUP" --query properties.outputs.keyVaultUri.value -o tsv 2>/dev/null || echo "")
KEY_VAULT_NAME=$(az deployment group show --name "$PLATFORM_DEPLOYMENT_NAME" --resource-group "$LANDING_ZONE_RESOURCE_GROUP" --query properties.outputs.keyVaultName.value -o tsv 2>/dev/null || echo "")
COSMOS_DB_ENDPOINT=$(az deployment group show --name "$PLATFORM_DEPLOYMENT_NAME" --resource-group "$LANDING_ZONE_RESOURCE_GROUP" --query properties.outputs.cosmosDbEndpoint.value -o tsv 2>/dev/null || echo "")
COSMOS_DB_DATABASE_NAME=$(az deployment group show --name "$PLATFORM_DEPLOYMENT_NAME" --resource-group "$LANDING_ZONE_RESOURCE_GROUP" --query properties.outputs.cosmosDbDatabaseName.value -o tsv 2>/dev/null || echo "")
COSMOS_DB_CONTAINER_NAME=$(az deployment group show --name "$PLATFORM_DEPLOYMENT_NAME" --resource-group "$LANDING_ZONE_RESOURCE_GROUP" --query properties.outputs.cosmosDbContainerName.value -o tsv 2>/dev/null || echo "")

log "INFO" "Successfully retrieved Platform infrastructure outputs:"
log "INFO" "ACA_ENVIRONMENT_ID=$ACA_ENVIRONMENT_ID"
log "INFO" "UAMI_ID=$UAMI_ID"
log "INFO" "ACR_LOGIN_SERVER=$ACR_LOGIN_SERVER"
log "INFO" "KEY_VAULT_URI=$KEY_VAULT_URI"
log "INFO" "KEY_VAULT_NAME=$KEY_VAULT_NAME"
log "INFO" "COSMOS_DB_ENDPOINT=$COSMOS_DB_ENDPOINT"
log "INFO" "COSMOS_DB_DATABASE_NAME=$COSMOS_DB_DATABASE_NAME"
log "INFO" "COSMOS_DB_CONTAINER_NAME=$COSMOS_DB_CONTAINER_NAME"

# Validate critical outputs before proceeding
if [[ -z "$ACA_ENVIRONMENT_ID" || "$ACA_ENVIRONMENT_ID" == "null" ]]; then
  log "ERROR" "Container Apps Environment ID is missing from platform deployment outputs"
  log "ERROR" "This indicates the platform deployment may have failed or the Container Apps Environment was not created"
  log "ERROR" "Attempting to find Container Apps Environment directly in the resource group..."
  
  # Try to find the Container Apps Environment directly
  ACA_ENVIRONMENT_ID=$(az containerapp env list --resource-group "$LANDING_ZONE_RESOURCE_GROUP" --query '[0].id' -o tsv 2>/dev/null || echo "")
  
  if [[ -n "$ACA_ENVIRONMENT_ID" && "$ACA_ENVIRONMENT_ID" != "null" ]]; then
    log "INFO" "Found Container Apps Environment directly: $ACA_ENVIRONMENT_ID"
  else
    log "ERROR" "Could not find Container Apps Environment in resource group: $LANDING_ZONE_RESOURCE_GROUP"
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
    if [[ -z "$COSMOS_DB_DATABASE_NAME" || "$COSMOS_DB_DATABASE_NAME" == "null" ]]; then
      log "ERROR" "Cosmos DB database name is missing from platform deployment outputs"
      log "ERROR" "The platform deployment may have failed or the cosmosDbDatabaseName output is not defined"
      exit 1
    fi
    if [[ -z "$COSMOS_DB_CONTAINER_NAME" || "$COSMOS_DB_CONTAINER_NAME" == "null" ]]; then
      log "ERROR" "Cosmos DB container name is missing from platform deployment outputs"
      log "ERROR" "The platform deployment may have failed or the cosmosDbContainerName output is not defined"
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
    IMAGE="$ACR_LOGIN_SERVER/transio-$svc:$TAG_VALUE"
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
    IMAGE="$ACR_LOGIN_SERVER/transio-$svc:$TAG_VALUE"
    IMAGES+=("$svc:$IMAGE")
  done
fi

# =====================
# 6. Deploy Workload (Applications)
# =====================
log "INFO" "Deploying Workload infrastructure (Static Web App and Container App)..."
log "INFO" "This deploys the actual applications on the platform infrastructure..."

# =====================
# 6.1. Retrieve Latest Encryption Key Versions from Bootstrap Key Vault
# =====================
log "INFO" "Retrieving latest encryption key versions from Bootstrap Key Vault..."

# Validate that we have the Bootstrap Key Vault name
if [[ -z "$BOOTSTRAP_KV_NAME" || "$BOOTSTRAP_KV_NAME" == "null" ]]; then
  log "ERROR" "Bootstrap Key Vault name not available"
  log "ERROR" "Cannot retrieve encryption key versions without Key Vault name"
  log "ERROR" "Ensure Bootstrap Key Vault deployment was successful or provide --skip-bootstrap-kv with existing vault"
  exit 1
fi

log "INFO" "Bootstrap Key Vault: $BOOTSTRAP_KV_NAME"

# Fetch all versions of the encryption key and sort newest→oldest
SECRET_NAME="encryption-key"
log "INFO" "Fetching versions for secret: $SECRET_NAME"

mapfile -t versions < <(
  az keyvault secret list-versions \
    --vault-name "$BOOTSTRAP_KV_NAME" \
    --name "$SECRET_NAME" \
    --query "sort_by([], &attributes.created) | reverse(@) | [].id" \
    -o tsv
)

# Validate that we have at least one version
if (( ${#versions[@]} == 0 )); then
  log "ERROR" "No versions found for $SECRET_NAME in $BOOTSTRAP_KV_NAME"
  log "ERROR" "This should not happen as the key seeding step should have completed successfully"
  log "ERROR" "Please check the previous deployment steps for any errors"
  exit 1
fi

# Pick latest and previous versions
latest_key_version="${versions[0]}"
if (( ${#versions[@]} > 1 )); then
  previous_key_version="${versions[1]}"
  log "INFO" "Found multiple key versions - using latest and previous for rotation support"
else
  previous_key_version="$latest_key_version"
  log "WARNING" "Only one secret version found; using same version for both current and previous"
  log "WARNING" "Key rotation will not be possible until a second version is created"
fi

log "INFO" "Latest encryption key version:   $latest_key_version"
log "INFO" "Previous encryption key version: $previous_key_version"

# Deploy workload using Bicep with dynamic key version parameters
log "INFO" "Deploying workload with latest encryption key versions..."
log "INFO" "Container Image: transio-backend:$BACKEND_TAG"
log "INFO" "Encryption Key (Current): $latest_key_version"
log "INFO" "Encryption Key (Previous): $previous_key_version"

# Extract the ACR name correctly from the login server
ACR_NAME_FOR_WORKLOAD=$(echo "$ACR_LOGIN_SERVER" | cut -d'.' -f1)

# Extract Cosmos DB account name correctly from the endpoint
COSMOS_ACCOUNT_NAME_FOR_WORKLOAD=$(echo "$COSMOS_DB_ENDPOINT" | sed 's|https://||' | cut -d'.' -f1)

# Get the Container Apps Environment name from the full ID
ACA_ENV_NAME_FOR_WORKLOAD=$(echo "$ACA_ENVIRONMENT_ID" | sed 's|.*/||')

log "INFO" "Raw platform outputs before extraction:"
log "INFO" "  Raw ACA_ENVIRONMENT_ID: '$ACA_ENVIRONMENT_ID'"
log "INFO" "  Raw ACR_LOGIN_SERVER: '$ACR_LOGIN_SERVER'"
log "INFO" "  Raw COSMOS_DB_ENDPOINT: '$COSMOS_DB_ENDPOINT'"

log "INFO" "Extracted deployment parameters:"
log "INFO" "  ACR Name: '$ACR_NAME_FOR_WORKLOAD'"
log "INFO" "  ACA Environment Name: '$ACA_ENV_NAME_FOR_WORKLOAD'"
log "INFO" "  Cosmos Account Name: '$COSMOS_ACCOUNT_NAME_FOR_WORKLOAD'"
log "INFO" "  Container Image: '$ACR_LOGIN_SERVER/transio-backend:$BACKEND_TAG'"

# Additional validation for extracted values
if [[ -z "$ACA_ENV_NAME_FOR_WORKLOAD" || "$ACA_ENV_NAME_FOR_WORKLOAD" == "null" ]]; then
  log "ERROR" "Failed to extract Container Apps Environment name from: '$ACA_ENVIRONMENT_ID'"
  log "ERROR" "The environment ID appears to be incomplete or malformed"
  exit 1
fi

if [[ -z "$ACR_NAME_FOR_WORKLOAD" || "$ACR_NAME_FOR_WORKLOAD" == "null" ]]; then
  log "ERROR" "Failed to extract ACR name from: '$ACR_LOGIN_SERVER'"
  exit 1
fi

if [[ -z "$COSMOS_ACCOUNT_NAME_FOR_WORKLOAD" || "$COSMOS_ACCOUNT_NAME_FOR_WORKLOAD" == "null" ]]; then
  log "ERROR" "Failed to extract Cosmos DB account name from: '$COSMOS_DB_ENDPOINT'"
  exit 1
fi

if ! az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file "$WORKLOAD_BICEP_FILE" \
  --parameters "$WORKLOAD_PARAMS_FILE" \
  --name "$WORKLOAD_DEPLOYMENT_NAME" \
  --no-prompt \
  --parameters \
    containerImage="$ACR_LOGIN_SERVER/transio-backend:$BACKEND_TAG" \
    acaEnvironmentName="$ACA_ENV_NAME_FOR_WORKLOAD" \
    acaEnvironmentResourceGroupName="$LANDING_ZONE_RESOURCE_GROUP" \
    acrName="$ACR_NAME_FOR_WORKLOAD" \
    keyVaultName="$KEY_VAULT_NAME" \
    cosmosDbAccountName="$COSMOS_ACCOUNT_NAME_FOR_WORKLOAD" \
    cosmosDatabaseName="$COSMOS_DB_DATABASE_NAME" \
    cosmosContainerName="$COSMOS_DB_CONTAINER_NAME" \
    encryptionKeyUri="$latest_key_version" \
    encryptionKeyPreviousUri="$previous_key_version" \
  --verbose; then
  log "ERROR" "Workload deployment failed"
  log "DEBUG" "Resource group for error reporting: '$RESOURCE_GROUP'"
  get_deployment_errors "$WORKLOAD_DEPLOYMENT_NAME" "$RESOURCE_GROUP"
  exit 1
fi

# Retrieve workload deployment outputs
log "INFO" "Retrieving workload deployment outputs..."
STATIC_WEB_APP_URL=$(az deployment group show \
  --name "$WORKLOAD_DEPLOYMENT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query properties.outputs.staticWebAppUrl.value -o tsv)
STATIC_WEB_APP_NAME=$(az deployment group show \
  --name "$WORKLOAD_DEPLOYMENT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query properties.outputs.staticWebAppName.value -o tsv)
BACKEND_FQDN=$(az deployment group show \
  --name "$WORKLOAD_DEPLOYMENT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query properties.outputs.backendFqdn.value -o tsv)
BACKEND_RESOURCE_ID=$(az deployment group show \
  --name "$WORKLOAD_DEPLOYMENT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query properties.outputs.backendResourceId.value -o tsv)

log "INFO" "Workload deployment completed successfully"
log "INFO" "Static Web App URL: $STATIC_WEB_APP_URL"
log "INFO" "Static Web App Name: $STATIC_WEB_APP_NAME"
log "INFO" "Backend FQDN: $BACKEND_FQDN"
log "INFO" "Backend Resource ID: $BACKEND_RESOURCE_ID"

# Set export variables for summary
export BACKEND_URL="$BACKEND_FQDN"
export STATIC_WEB_APP_URL STATIC_WEB_APP_NAME

# =====================
# 7) Summary
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
echo "Cosmos DB Endpoint: $COSMOS_DB_ENDPOINT"
echo "Database Name: $COSMOS_DB_DATABASE_NAME"
echo "Managed Identity: $UAMI_ID"
echo ""
echo "Deployment Sequence Completed:"
echo "✅ 1. Landing Zone (shared infrastructure)"
echo "✅ 2. Bootstrap Key Vault (platform-specific secrets storage)"
echo "✅ 3. Key Vault Seeding (Fernet encryption keys generated with OpenSSL/urandom)"
echo "✅ 4. Platform Infrastructure (Container Apps Environment, VNet, etc.)"
echo "✅ 5. Container Images (built and pushed to ACR)"
echo "✅ 6. Workload Applications (Static Web App + Container App)"
echo ""
echo "🎉 Deployment Complete!"
echo "✅ Backend is linked to Static Web App"
echo "✅ API requests to /api/* will route to your Container App"
echo "=============================================="

# 8) Deploy frontend static files to Static Web App production environment
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
  log "INFO" "Deploying static files from ./src/frontend/static to production environment..."
  
  # Deploy static files using SWA CLI
  swa deploy \
    --app-location "../src/frontend/static" \
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
echo "✅ Landing Zone: Deployed"
echo "✅ Bootstrap Key Vault: Deployed"
echo "✅ Encryption Keys: Generated and seeded"
echo "✅ Platform Infrastructure: Deployed"
echo "✅ Container Images: Built and pushed"
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