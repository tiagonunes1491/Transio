#!/bin/bash
# =====================================================
# Modular Landing Zone Deployment Script
# =====================================================
#
# This script provides modular deployment capabilities for the Secure Secret Sharer
# landing zone infrastructure. It supports deploying specific components independently
# or as a complete solution.
#
# Components:
# - Shared: Common infrastructure (artifacts RG, shared UAMIs, ACR permissions)
# - K8S: Kubernetes-specific resources (AKS spoke RG, K8S UAMIs, RBAC)
# - PaaS: Platform-as-a-Service resources (Container Apps spoke RG, PaaS UAMIs, RBAC)
#
# Usage Examples:
#   ./deploy-landing-zone.sh shared    # Deploy only shared infrastructure
#   ./deploy-landing-zone.sh k8s       # Deploy shared + K8S landing zone
#   ./deploy-landing-zone.sh paas      # Deploy shared + PaaS landing zone
#   ./deploy-landing-zone.sh all       # Deploy everything (shared + K8S + PaaS)
#   ./deploy-landing-zone.sh teardown  # Delete all landing zone resource groups
#
# Prerequisites:
# - Azure CLI installed and authenticated (az login)
# - Appropriate permissions to create subscriptions-level resources
# - GitHub repository configured for OIDC (update .bicepparam files with org/repo)
#
# =====================================================

set -e  # Exit on any error

# =====================================================
# Configuration Variables
# =====================================================

# Deployment names with timestamps for uniqueness
DEPLOYMENT_NAME="landing-zone-full-$(date +%Y%m%d-%H%M%S)"
SHARED_DEPLOYMENT_NAME="landing-zone-shared-$(date +%Y%m%d-%H%M%S)"
K8S_DEPLOYMENT_NAME="landing-zone-k8s-$(date +%Y%m%d-%H%M%S)"
PAAS_DEPLOYMENT_NAME="landing-zone-paas-$(date +%Y%m%d-%H%M%S)"

# Bicep template and parameter file paths
BICEP_FILE="../infra/landing-zone.bicep"
PARAMS_FILE="../infra/landing-zone.dev.bicepparam"
SHARED_BICEP_FILE="../infra/landing-zone-shared.bicep"
SHARED_PARAMS_FILE="../infra/landing-zone-shared.bicepparam"
K8S_BICEP_FILE="../infra/landing-zone-k8s.bicep"
K8S_PARAMS_FILE="../infra/landing-zone-k8s.bicepparam"
PAAS_BICEP_FILE="../infra/landing-zone-paas.bicep"
PAAS_PARAMS_FILE="../infra/landing-zone-paas.bicepparam"

# Azure deployment configuration
SUBSCRIPTION_SCOPE="subscription"

# =====================================================
# Helper Functions
# =====================================================

# Function to delete a resource group if it exists
function delete_rg() {
  RG_NAME="$1"
  if az group exists --name "$RG_NAME" | grep -q true; then
    echo "🗑️  Deleting resource group: $RG_NAME ..."
    az group delete --name "$RG_NAME" --yes --no-wait
  else
    echo "ℹ️  Resource group $RG_NAME does not exist."
  fi
}

# Function to perform complete teardown of all landing zone resources
function teardown_all() {
  echo "⚠️  Tearing down all landing zone resource groups..."
  echo "   This will delete ALL landing zone infrastructure!"
  echo ""
  
  # List of all possible resource groups to delete (update as needed)
  delete_rg "rg-ssharer-mgmt-shared"
  delete_rg "rg-ssharer-artifacts-hub"
  delete_rg "rg-ssharer-mgmt-dev"
  delete_rg "rg-ssharer-k8s-spoke-dev"
  delete_rg "rg-ssharer-paas-spoke-dev"
  # Add more environment-specific RGs as needed (staging, prod, etc.)
  
  echo ""
  echo "✅ Teardown initiated. Resource group deletions are running in background."
  echo "   Use 'az group list' to monitor deletion progress."
}

# Function to show what-if analysis for a deployment
function show_whatif() {
  local deployment_name="$1"
  local bicep_file="$2"
  local params_file="$3"
  local description="$4"
  
  echo ""
  echo "🔍 $description What-If Analysis:"
  echo "=================================================="
  az deployment sub what-if \
    --name "$deployment_name" \
    --location "spaincentral" \
    --template-file "$bicep_file" \
    --parameters "$params_file"
  echo "=================================================="
}

# Function to deploy shared infrastructure (no user prompts)
function deploy_shared() {
  echo "🛠️  Deploying shared infrastructure..."
  az deployment sub create \
    --name "$SHARED_DEPLOYMENT_NAME" \
    --location "spaincentral" \
    --template-file "$SHARED_BICEP_FILE" \
    --parameters "$SHARED_PARAMS_FILE" \
    --output json
  if [ $? -ne 0 ]; then
    echo "❌ Shared infrastructure deployment failed!"
    exit 1
  fi
  echo "✅ Shared infrastructure deployment completed successfully!"
  echo ""
}

# Function to deploy K8S landing zone (no user prompts)
function deploy_k8s() {
  echo "🛠️  Deploying K8S landing zone infrastructure..."
  az deployment sub create \
    --name "$K8S_DEPLOYMENT_NAME" \
    --location "spaincentral" \
    --template-file "$K8S_BICEP_FILE" \
    --parameters "$K8S_PARAMS_FILE" \
    --output json
  if [ $? -ne 0 ]; then
    echo "❌ K8S landing zone deployment failed!"
    exit 1
  fi
  echo "✅ K8S landing zone deployment completed successfully!"
  echo ""
}

# Function to deploy PaaS landing zone (no user prompts)
function deploy_paas() {
  echo "🛠️  Deploying PaaS landing zone infrastructure..."
  az deployment sub create \
    --name "$PAAS_DEPLOYMENT_NAME" \
    --location "spaincentral" \
    --template-file "$PAAS_BICEP_FILE" \
    --parameters "$PAAS_PARAMS_FILE" \
    --output json
  if [ $? -ne 0 ]; then
    echo "❌ PaaS landing zone deployment failed!"
    exit 1
  fi
  echo "✅ PaaS landing zone deployment completed successfully!"
  echo ""
}

# Function to deploy all landing zone components
function deploy_all() {
  echo "🚀 Deploying Complete Landing Zone Infrastructure..."
  echo "   This will deploy shared, K8S, and PaaS landing zones."
  echo ""
  
  # Show all what-if analyses upfront
  show_whatif "$SHARED_DEPLOYMENT_NAME" "$SHARED_BICEP_FILE" "$SHARED_PARAMS_FILE" "Shared Infrastructure"
  show_whatif "$K8S_DEPLOYMENT_NAME" "$K8S_BICEP_FILE" "$K8S_PARAMS_FILE" "K8S Landing Zone"
  show_whatif "$PAAS_DEPLOYMENT_NAME" "$PAAS_BICEP_FILE" "$PAAS_PARAMS_FILE" "PaaS Landing Zone"

  echo ""
  echo "📋 Summary of changes above:"
  echo "   - Shared: Common infrastructure (artifacts RG, shared UAMIs, ACR permissions)"
  echo "   - K8S: Kubernetes resources (K8S spoke RG, K8S UAMIs, RBAC)"
  echo "   - PaaS: Platform-as-a-Service resources (PaaS spoke RG, PaaS UAMIs, RBAC)"
  echo ""
  read -p "Do you want to proceed with ALL landing zone deployments? (y/N): " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Complete landing zone deployment cancelled by user."
    exit 0
  fi

  # Deploy all components without further prompts
  deploy_shared
  deploy_k8s
  deploy_paas

  echo "✅ Complete landing zone deployment completed successfully!"
  echo ""
}

# =====================================================
# Main Script Logic
# =====================================================

ACTION="$1"

# Display usage information if no action is provided
if [ -z "$ACTION" ]; then
  echo "❌ Error: No action specified"
  echo ""
  echo "Usage: $0 [ACTION]"
  echo ""
  echo "Available Actions:"
  echo "  teardown  - Delete all landing zone resource groups"
  echo "  shared    - Deploy only shared infrastructure"
  echo "  k8s       - Deploy shared + K8S landing zone"
  echo "  paas      - Deploy shared + PaaS landing zone"
  echo "  all       - Deploy everything (shared + K8S + PaaS)"
  echo ""
  echo "Examples:"
  echo "  $0 shared    # Deploy shared infrastructure only"
  echo "  $0 k8s       # Deploy for Kubernetes workloads"
  echo "  $0 paas      # Deploy for PaaS workloads"
  echo "  $0 all       # Deploy complete landing zone"
  echo "  $0 teardown  # Clean up all resources"
  echo ""
  exit 1
fi

# Validate Azure authentication before proceeding
echo "🔐 Checking Azure authentication..."
if ! az account show &> /dev/null; then
    echo "❌ Not logged into Azure. Please run 'az login' first."
    exit 1
fi

# Display current subscription information
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
echo "✅ Authenticated to subscription: $SUBSCRIPTION_NAME ($SUBSCRIPTION_ID)"
echo ""

# Execute the requested action
case "$ACTION" in
  teardown)
    echo "⚠️  TEARDOWN MODE: This will delete ALL landing zone infrastructure!"
    echo ""
    read -p "Are you sure you want to proceed with teardown? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo "❌ Teardown cancelled by user."
      exit 0
    fi
    teardown_all
    ;;
  shared)
    echo "🏗️  Deploying Shared Landing Zone Infrastructure..."
    echo "   - Shared artifacts resource group"
    echo "   - Shared management identities"
    echo "   - ACR push permissions"
    echo ""
    
    # Show what-if analysis first
    show_whatif "$SHARED_DEPLOYMENT_NAME" "$SHARED_BICEP_FILE" "$SHARED_PARAMS_FILE" "Shared Infrastructure"
    
    echo ""
    read -p "Do you want to proceed with the shared infrastructure deployment? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo "❌ Shared infrastructure deployment cancelled by user."
      exit 0
    fi
    
    deploy_shared
    ;;
  k8s)
    echo "🐳 Deploying K8S Landing Zone Infrastructure..."
    echo "   - K8S spoke resource group"
    echo "   - K8S workload identities (k8s, k8sDeploy)"
    echo "   - GitHub federated credentials"
    echo "   - RBAC assignments for AKS"
    echo ""
    
    # Show what-if analyses for both shared and K8S
    show_whatif "$SHARED_DEPLOYMENT_NAME" "$SHARED_BICEP_FILE" "$SHARED_PARAMS_FILE" "Shared Infrastructure"
    show_whatif "$K8S_DEPLOYMENT_NAME" "$K8S_BICEP_FILE" "$K8S_PARAMS_FILE" "K8S Landing Zone"
    
    echo ""
    echo "📋 This will deploy shared infrastructure + K8S landing zone"
    read -p "Do you want to proceed with shared + K8S deployments? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo "❌ K8S landing zone deployment cancelled by user."
      exit 0
    fi
    
    deploy_shared
    deploy_k8s
    ;;
  paas)
    echo "☁️  Deploying PaaS Landing Zone Infrastructure..."
    echo "   - PaaS spoke resource group"
    echo "   - PaaS workload identities"
    echo "   - GitHub federated credentials"
    echo "   - RBAC assignments for Container Apps/Static Web Apps"
    echo ""
    
    # Show what-if analyses for both shared and PaaS
    show_whatif "$SHARED_DEPLOYMENT_NAME" "$SHARED_BICEP_FILE" "$SHARED_PARAMS_FILE" "Shared Infrastructure"
    show_whatif "$PAAS_DEPLOYMENT_NAME" "$PAAS_BICEP_FILE" "$PAAS_PARAMS_FILE" "PaaS Landing Zone"
    
    echo ""
    echo "📋 This will deploy shared infrastructure + PaaS landing zone"
    read -p "Do you want to proceed with shared + PaaS deployments? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo "❌ PaaS landing zone deployment cancelled by user."
      exit 0
    fi
    
    deploy_shared
    deploy_paas
    ;;
  all)
    deploy_all
    ;;
  *)
    echo "❌ Unknown action: $ACTION"
    echo ""
    echo "Valid actions: teardown, shared, k8s, paas, all"
    echo "Run '$0' without arguments for detailed usage information."
    exit 1
    ;;
esac

echo "🎉 Script execution completed successfully!"
echo ""
echo "📋 Next Steps:"
echo "1. Verify resource groups are created in the Azure portal"
echo "2. Update GitHub repository secrets with UAMI client IDs"
echo "3. Deploy workload-specific infrastructure (AKS, Container Apps, etc.)"
echo "4. Test GitHub Actions workflows with federated authentication"

exit 0
