#!/usr/bin/env bash
set -euo pipefail

# build_swa-aca.sh - SWA deployment for Secure Secret Sharer on Azure Container Apps + Static Web Apps
# This script leverages the modular landing zone deployment with proper deployment sequence:
# 1. Landing Zone (shared infrastructure + networking)
# 2. Bootstrap Key Vault (platform-specific secrets management) 
# 3. Key Vault Seeding (generate and store Fernet encryption keys)
# 4. Platform Infrastructure (Container Apps Environment, Cosmos DB, etc.)
# 5. Workload Applications (Static Web App + Container App)
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
  
  # Delete resource group deployments first (if they exist)
  if RESOURCE_GROUP=$(az deployment sub show --name "$PLATFORM_DEPLOYMENT_NAME" --query properties.outputs.resourceGroupName.value -o tsv 2>/dev/null) && [[ -n "$RESOURCE_GROUP" && "$RESOURCE_GROUP" != "null" ]]; then
    log "INFO" "Deleting workload deployment..."
    az deployment group delete --name "$WORKLOAD_DEPLOYMENT_NAME" --resource-group "$RESOURCE_GROUP" --verbose 2>/dev/null || true
    
    log "INFO" "Deleting resource group: $RESOURCE_GROUP"
    az group delete --name "$RESOURCE_GROUP" --yes --no-wait --verbose 2>/dev/null || true
  fi
  
  # Delete subscription-level deployments
  log "INFO" "Deleting platform deployment..."
  az deployment sub delete --name "$PLATFORM_DEPLOYMENT_NAME" --verbose 2>/dev/null || true
  
  log "INFO" "Deleting bootstrap Key Vault deployment..."
  az deployment sub delete --name "$BOOTSTRAP_KV_DEPLOYMENT_NAME" --verbose 2>/dev/null || true
  
  # Use the landing zone teardown functionality
  ./deploy-landing-zone.sh teardown
  log "INFO" "Teardown completed successfully"
  exit 0
fi

if [[ "$FULL_REBUILD" == true ]]; then
  log "INFO" "Full rebuild requested: tearing down all deployments and landing zone..."
  
  # Delete resource group deployments first (if they exist)
  if RESOURCE_GROUP=$(az deployment sub show --name "$PLATFORM_DEPLOYMENT_NAME" --query properties.outputs.resourceGroupName.value -o tsv 2>/dev/null) && [[ -n "$RESOURCE_GROUP" && "$RESOURCE_GROUP" != "null" ]]; then
    log "INFO" "Deleting workload deployment..."
    az deployment group delete --name "$WORKLOAD_DEPLOYMENT_NAME" --resource-group "$RESOURCE_GROUP" --verbose 2>/dev/null || true
    
    log "INFO" "Deleting resource group: $RESOURCE_GROUP"
    az group delete --name "$RESOURCE_GROUP" --yes --no-wait --verbose 2>/dev/null || true
  fi
  
  # Delete subscription-level deployments
  log "INFO" "Deleting platform deployment..."
  az deployment sub delete --name "$PLATFORM_DEPLOYMENT_NAME" --verbose 2>/dev/null || true
  
  log "INFO" "Deleting bootstrap Key Vault deployment..."
  az deployment sub delete --name "$BOOTSTRAP_KV_DEPLOYMENT_NAME" --verbose 2>/dev/null || true
  
  # Use the landing zone teardown functionality
  ./deploy-landing-zone.sh teardown
  log "INFO" "Teardown completed"
fi

# =====================
# 1. Deploy Landing Zone (Shared Infrastructure)
# =====================
if [[ "$SKIP_LANDING_ZONE" == false ]]; then
  log "INFO" "Deploying landing zone (shared infrastructure + networking)..."
  log "INFO" "This includes user-assigned managed identities and GitHub federation..."
  ./deploy-landing-zone.sh paas
  log "INFO" "Landing zone deployment completed"
else
  log "INFO" "Skipping landing zone deployment"
fi

# =====================
# 2. Deploy Bootstrap Key Vault 
# =====================
if [[ "$SKIP_BOOTSTRAP_KV" == false ]]; then
  log "INFO" "Deploying Bootstrap Key Vault for SWA platform..."
  log "INFO" "This creates the platform-specific Key Vault that will be used by the platform infrastructure..."
  if ! az deployment sub create \
    --template-file "$BOOTSTRAP_KV_BICEP_FILE" \
    --parameters "$BOOTSTRAP_KV_PARAMS_FILE" \
    --location "$LOCATION" \
    --name "$BOOTSTRAP_KV_DEPLOYMENT_NAME" \
    --verbose; then
    log "ERROR" "Bootstrap Key Vault deployment failed"
    get_deployment_errors "$BOOTSTRAP_KV_DEPLOYMENT_NAME"
    exit 1
  fi
  log "INFO" "Bootstrap Key Vault deployment completed"
  
  # Retrieve Key Vault name from deployment outputs
  log "INFO" "Retrieving Key Vault name from Bootstrap deployment..."
  BOOTSTRAP_KV_NAME=$(az deployment sub show --name "$BOOTSTRAP_KV_DEPLOYMENT_NAME" --query properties.outputs.keyVaultName.value -o tsv)
  
  if [[ -z "$BOOTSTRAP_KV_NAME" || "$BOOTSTRAP_KV_NAME" == "null" ]]; then
    log "ERROR" "Failed to retrieve Key Vault name from Bootstrap deployment"
    exit 1
  fi
  
  log "INFO" "Bootstrap Key Vault name: $BOOTSTRAP_KV_NAME"
  
  # =====================
  # 2.1. Seed Bootstrap Key Vault with Encryption Keys
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
  BOOTSTRAP_KV_NAME=$(az deployment sub show --name "$BOOTSTRAP_KV_DEPLOYMENT_NAME" --query properties.outputs.keyVaultName.value -o tsv 2>/dev/null || echo "")
  
  if [[ -z "$BOOTSTRAP_KV_NAME" || "$BOOTSTRAP_KV_NAME" == "null" ]]; then
    log "WARNING" "Could not retrieve Bootstrap Key Vault name from existing deployment"
    log "WARNING" "Platform deployment may fail if it requires Key Vault references"
    # Set a default based on naming convention from the bicep file
    BOOTSTRAP_KV_NAME="ss-dev-swa-kv"
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
  if ! az deployment sub create \
    --template-file "$PLATFORM_BICEP_FILE" \
    --parameters "$PLATFORM_PARAMS_FILE" \
    --location "$LOCATION" \
    --name "$PLATFORM_DEPLOYMENT_NAME" \
    --verbose; then
    log "ERROR" "SWA Platform infrastructure deployment failed"
    get_deployment_errors "$PLATFORM_DEPLOYMENT_NAME"
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
RESOURCE_GROUP=$(az deployment sub show --name "$PLATFORM_DEPLOYMENT_NAME" --query properties.outputs.resourceGroupName.value -o tsv)
ACA_ENVIRONMENT_ID=$(az deployment sub show --name "$PLATFORM_DEPLOYMENT_NAME" --query properties.outputs.acaEnvironmentId.value -o tsv)
UAMI_ID=$(az deployment sub show --name "$PLATFORM_DEPLOYMENT_NAME" --query properties.outputs.uamiId.value -o tsv)
ACR_LOGIN_SERVER=$(az deployment sub show --name "$PLATFORM_DEPLOYMENT_NAME" --query properties.outputs.acrLoginServer.value -o tsv)
KEY_VAULT_URI=$(az deployment sub show --name "$PLATFORM_DEPLOYMENT_NAME" --query properties.outputs.keyVaultUri.value -o tsv)
KEY_VAULT_NAME=$(az deployment sub show --name "$PLATFORM_DEPLOYMENT_NAME" --query properties.outputs.keyVaultName.value -o tsv)
COSMOS_DB_ENDPOINT=$(az deployment sub show --name "$PLATFORM_DEPLOYMENT_NAME" --query properties.outputs.cosmosDbEndpoint.value -o tsv)
COSMOS_DB_DATABASE_NAME=$(az deployment sub show --name "$PLATFORM_DEPLOYMENT_NAME" --query properties.outputs.cosmosDbDatabaseName.value -o tsv)
COSMOS_DB_CONTAINER_NAME=$(az deployment sub show --name "$PLATFORM_DEPLOYMENT_NAME" --query properties.outputs.cosmosDbContainerName.value -o tsv)

log "INFO" "Successfully retrieved Platform infrastructure outputs:"
log "INFO" "RESOURCE_GROUP=$RESOURCE_GROUP"
log "INFO" "ACA_ENVIRONMENT_ID=$ACA_ENVIRONMENT_ID"
log "INFO" "UAMI_ID=$UAMI_ID"
log "INFO" "ACR_LOGIN_SERVER=$ACR_LOGIN_SERVER"
log "INFO" "KEY_VAULT_URI=$KEY_VAULT_URI"
log "INFO" "KEY_VAULT_NAME=$KEY_VAULT_NAME"
log "INFO" "COSMOS_DB_ENDPOINT=$COSMOS_DB_ENDPOINT"
log "INFO" "COSMOS_DB_DATABASE_NAME=$COSMOS_DB_DATABASE_NAME"
log "INFO" "COSMOS_DB_CONTAINER_NAME=$COSMOS_DB_CONTAINER_NAME"

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
log "INFO" "Container Image: secure-secret-sharer-backend:$BACKEND_TAG"
log "INFO" "Encryption Key (Current): $latest_key_version"
log "INFO" "Encryption Key (Previous): $previous_key_version"

if ! az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file "$WORKLOAD_BICEP_FILE" \
  --parameters "$WORKLOAD_PARAMS_FILE" \
  --name "$WORKLOAD_DEPLOYMENT_NAME" \
  --parameters \
    containerImage="secure-secret-sharer-backend:$BACKEND_TAG" \
    environmentId="$ACA_ENVIRONMENT_ID" \
    userAssignedIdentityId="$UAMI_ID" \
    acrLoginServer="$ACR_LOGIN_SERVER" \
    keyVaultUri="$KEY_VAULT_URI" \
    cosmosDbEndpoint="$COSMOS_DB_ENDPOINT" \
    cosmosDatabaseName="$COSMOS_DB_DATABASE_NAME" \
    cosmosContainerName="$COSMOS_DB_CONTAINER_NAME" \
    encryptionKeyUri="$latest_key_version" \
    encryptionKeyPreviousUri="$previous_key_version" \
  --verbose; then
  log "ERROR" "Workload deployment failed"
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