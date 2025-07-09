#!/bin/bash
# ========================# File paths updated for actual folder structure
# - 0-landing-zone: All landing zone components (shared, k8s, paas)=========================
# Modular Landing Zone Deployment Script
# =====================================================
#
# This script provides modular deployment capabilities for the Secure Secret Sharer
# landing zone infrastructure. It supports deploying specific components independently
# or as a complete solution.
#
# Components:
# - Shared: Common infrastructure (artifacts RG, shared UAMIs, ACR permissions)
#   Location: infra/0-landing-zone/
# - K8S: Kubernetes-specific resources (AKS spoke RG, K8S UAMIs, RBAC)
#   Location: infra/0-landing-zone/
# - PaaS: Platform-as-a-Service resources (Container Apps spoke RG, PaaS UAMIs, RBAC)
#   Location: infra/0-landing-zone/
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
# - Bicep files organized in modular structure:
#   - infra/0-landing-zone/ (all landing zone components)
#
# =====================================================

set -e  # Exit on any error

# =====================================================
# Configuration Variables
# =====================================================
# Note: File paths updated for new modular structure
# - 10-lz-shared: Shared/common infrastructure
# - 11-lz-aks: Kubernetes-specific landing zone
# - 12-lz-paas: PaaS-specific landing zone

# Verbose output configuration
VERBOSE=true

# Deployment names with timestamps for uniqueness
DEPLOYMENT_NAME="landing-zone-full-$(date +%Y%m%d-%H%M%S)"
SHARED_DEPLOYMENT_NAME="landing-zone-shared-$(date +%Y%m%d-%H%M%S)"
K8S_DEPLOYMENT_NAME="landing-zone-k8s-$(date +%Y%m%d-%H%M%S)"
PAAS_DEPLOYMENT_NAME="landing-zone-paas-$(date +%Y%m%d-%H%M%S)"

# Bicep template and parameter file paths
# Note: Using 0-landing-zone for the actual existing structure
SHARED_BICEP_FILE="../infra/0-landing-zone/main.bicep"
K8S_BICEP_FILE="../infra/0-landing-zone/main.bicep"
PAAS_BICEP_FILE="../infra/0-landing-zone/main.bicep"

# Parameter files will be set based on environment after argument parsing

# Azure deployment configuration
SUBSCRIPTION_SCOPE="subscription"

# =====================================================
# Helper Functions
# =====================================================

# Function to log messages with timestamp
function log_info() {
  local message="$1"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $message"
}

function log_error() {
  local message="$1"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $message" >&2
}

function log_warning() {
  local message="$1"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $message"
}

# Function to validate template and parameters before deployment
function validate_deployment() {
  local bicep_file="$1"
  local params_file="$2"
  local description="$3"
  
  log_info "Validating $description template and parameters..."
  
  # Check if files exist
  if [ ! -f "$bicep_file" ]; then
    log_error "Bicep template file not found: $bicep_file"
    log_error "Current working directory: $(pwd)"
    log_error "Available .bicep files in ../infra/:"
    find ../infra/ -name "*.bicep" -type f 2>/dev/null || log_error "No .bicep files found"
    return 1
  fi
  
  if [ ! -f "$params_file" ]; then
    log_error "Parameters file not found: $params_file"
    log_error "Current working directory: $(pwd)"
    log_error "Available .bicepparam files in ../infra/:"
    find ../infra/ -name "*.bicepparam" -type f 2>/dev/null || log_error "No .bicepparam files found"
    return 1
  fi
  
  log_info "Files exist. Running template validation..."
  log_info "Template: $(realpath "$bicep_file")"
  log_info "Parameters: $(realpath "$params_file")"
  
  # Validate the template
  if ! az deployment sub validate \
    --location "spaincentral" \
    --template-file "$bicep_file" \
    --parameters "$params_file" \
    --output json > /dev/null 2>&1; then
    log_error "Template validation failed for $description"
    log_error "Run the validation manually for detailed errors:"
    log_error "az deployment sub validate --location spaincentral --template-file \"$bicep_file\" --parameters \"$params_file\""
    return 1
  fi
  
  log_info "Template validation passed for $description"
  return 0
}

# Function to analyze common deployment issues
function analyze_common_issues() {
  local deployment_name="$1"
  local bicep_file="$2"
  
  log_info "Analyzing common deployment issues..."
  
  # Check 1: Resource naming conflicts
  log_info "Checking for resource naming conflicts..."
  log_info "(Manual check - look for 'already exists' errors in deployment output)"
  
  # Check 2: Permission issues
  log_info "Checking for permission issues..."
  log_info "Current user roles:"
  az role assignment list --assignee $(az account show --query user.name -o tsv) --output table
  
  # Check 3: Resource provider registration
  log_info "Checking resource provider registration..."
  local providers_needed=("Microsoft.ManagedIdentity" "Microsoft.ContainerRegistry" "Microsoft.Resources")
  for provider in "${providers_needed[@]}"; do
    local status=$(az provider show --namespace "$provider" --query "registrationState" -o tsv 2>/dev/null || echo "Unknown")
    if [ "$status" != "Registered" ]; then
      log_error "ISSUE FOUND: Provider $provider is not registered (Status: $status)"
      log_error "Solution: Run 'az provider register --namespace $provider'"
    else
      log_info "✅ Provider $provider is registered"
    fi
  done
  
  # Check 4: Template syntax issues
  log_info "Checking Bicep template syntax..."
  if az bicep build --file "$bicep_file" --outfile /dev/null 2>/dev/null; then
    log_info "✅ Bicep template syntax is valid"
  else
    log_error "ISSUE FOUND: Bicep template syntax error!"
    log_error "Template validation output:"
    az bicep build --file "$bicep_file" --outfile /dev/null 2>&1
  fi
  
  # Check 5: Subscription limits and quotas
  log_info "Checking subscription limits..."
  local core_usage=$(az vm list-usage --location "spaincentral" --query "[?name.value=='cores'].currentValue" -o tsv 2>/dev/null || echo "0")
  local core_limit=$(az vm list-usage --location "spaincentral" --query "[?name.value=='cores'].limit" -o tsv 2>/dev/null || echo "0")
  if [ "$core_limit" -gt 0 ]; then
    local usage_percent=$((core_usage * 100 / core_limit))
    if [ $usage_percent -gt 80 ]; then
      log_warning "High core usage: $core_usage/$core_limit ($usage_percent%)"
    else
      log_info "✅ Core usage within limits: $core_usage/$core_limit ($usage_percent%)"
    fi
  fi
}

# Function to get detailed deployment operation errors
function get_deployment_errors() {
  local deployment_name="$1"
  
  log_info "Retrieving detailed error information for deployment: $deployment_name"
  
  # Get deployment details
  log_info "Deployment status:"
  az deployment sub show \
    --name "$deployment_name" \
    --query "{name:name,state:properties.provisioningState,timestamp:properties.timestamp,error:properties.error}" \
    --output table
  
  # Get failed operations with more detail
  log_info "Failed operations:"
  az deployment operation sub list \
    --name "$deployment_name" \
    --query "[?properties.provisioningState=='Failed'].{Resource:properties.targetResource.resourceName,Type:properties.targetResource.resourceType,Error:properties.statusMessage.error.message,Code:properties.statusMessage.error.code}" \
    --output table 2>/dev/null || echo "Unable to retrieve operation details"
  
  # Get the full error JSON for the failed operations
  log_info "Detailed error information (JSON):"
  az deployment operation sub list \
    --name "$deployment_name" \
    --query "[?properties.provisioningState=='Failed'].{Resource:properties.targetResource.resourceName,FullError:properties.statusMessage}" \
    --output json 2>/dev/null || echo "Unable to retrieve detailed error information"
  
  # Get all operations for context
  log_info "All deployment operations:"
  az deployment operation sub list \
    --name "$deployment_name" \
    --query "[].{Resource:properties.targetResource.resourceName,Type:properties.targetResource.resourceType,State:properties.provisioningState,Timestamp:properties.timestamp}" \
    --output table 2>/dev/null || echo "Unable to retrieve operation list"
}

# Enhanced deployment function with comprehensive error handling
function deploy_with_logging() {
  local deployment_name="$1"
  local bicep_file="$2"
  local params_file="$3"
  local description="$4"
  
  log_info "Starting deployment: $description"
  log_info "Deployment name: $deployment_name"
  log_info "Template file: $bicep_file"
  log_info "Parameters file: $params_file"
  
  # Pre-deployment validation
  if ! validate_deployment "$bicep_file" "$params_file" "$description"; then
    return 1
  fi
  
  # Start timing
  local start_time=$(date +%s)
  log_info "Beginning Azure deployment..."
  
  # Attempt deployment with comprehensive logging
  log_info "Executing deployment command..."
  if az deployment sub create \
    --name "$deployment_name" \
    --location "spaincentral" \
    --template-file "$bicep_file" \
    --parameters "$params_file" \
    --no-prompt \
    --verbose; then
    
    # Success case
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log_info "$description deployment completed successfully in ${duration} seconds"
    
    # Show deployment outputs if any
    log_info "Deployment outputs:"
    az deployment sub show \
      --name "$deployment_name" \
      --query "properties.outputs" \
      --output table
    
    return 0
  else
    # Failure case
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log_error "$description deployment failed after ${duration} seconds"
    
    # Get detailed error information
    get_deployment_errors "$deployment_name"
    
    # Run common issue analysis
    analyze_common_issues "$deployment_name" "$bicep_file"
    
    # Additional diagnostic information
    log_info "Running additional diagnostics..."
    
    # Check Azure CLI version
    log_info "Azure CLI version:"
    az version
    
    # Check current subscription context
    log_info "Current Azure context:"
    az account show --query "{subscriptionId:id,subscriptionName:name,tenantId:tenantId,user:user.name}" --output table
    
    # Check resource providers
    log_info "Resource provider registration status:"
    az provider list --query "[?contains(['Microsoft.ManagedIdentity','Microsoft.ContainerRegistry','Microsoft.Resources'], namespace)].{Namespace:namespace,State:registrationState}" --output table
    
    return 1
  fi
}

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
  # For the current structure, shared and paas use the same template
  # This is essentially a no-op since PaaS deployment handles everything
  echo "🛠️  Shared infrastructure is included in PaaS deployment..."
}

# Function to deploy K8S landing zone (no user prompts)
function deploy_k8s() {
  echo "🛠️  Deploying K8S landing zone infrastructure..."
  if ! deploy_with_logging "$K8S_DEPLOYMENT_NAME" "$K8S_BICEP_FILE" "$K8S_PARAMS_FILE" "K8S Landing Zone"; then
    log_error "K8S landing zone deployment failed!"
    exit 1
  fi
  echo "✅ K8S landing zone deployment completed successfully!"
  echo ""
}

# Function to deploy PaaS landing zone (no user prompts)
function deploy_paas() {
  echo "🛠️  Deploying PaaS landing zone infrastructure..."
  if ! deploy_with_logging "$PAAS_DEPLOYMENT_NAME" "$PAAS_BICEP_FILE" "$PAAS_PARAMS_FILE" "PaaS Landing Zone"; then
    log_error "PaaS landing zone deployment failed!"
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
  echo "   - Shared (10-lz-shared): Common infrastructure (artifacts RG, shared UAMIs, ACR permissions)"
  echo "   - K8S (11-lz-aks): Kubernetes resources (K8S spoke RG, K8S UAMIs, RBAC)"
  echo "   - PaaS (12-lz-paas): Platform-as-a-Service resources (PaaS spoke RG, PaaS UAMIs, RBAC)"
  echo ""
  echo "🚀 Proceeding with ALL landing zone deployments (non-interactive mode)..."

  # Deploy all components without prompts
  deploy_shared
  deploy_k8s
  deploy_paas

  echo "✅ Complete landing zone deployment completed successfully!"
  echo ""
}

# Function to run diagnostics for troubleshooting
function run_diagnostics() {
  log_info "Running comprehensive Azure diagnostics..."
  
  # Check Azure CLI version
  log_info "Azure CLI version:"
  az version
  
  # Check authentication status
  log_info "Current Azure authentication:"
  az account show --output table
  
  # Check subscription access
  log_info "Available subscriptions:"
  az account list --query "[].{Name:name,SubscriptionId:id,State:state,IsDefault:isDefault}" --output table
  
  # Check resource provider registration
  log_info "Resource provider registration status:"
  az provider list --query "[?contains(['Microsoft.ManagedIdentity','Microsoft.ContainerRegistry','Microsoft.Resources','Microsoft.ContainerInstance','Microsoft.App'], namespace)].{Namespace:namespace,State:registrationState}" --output table
  
  # Check recent deployments
  log_info "Recent subscription deployments:"
  az deployment sub list --query "[].{Name:name,State:properties.provisioningState,Timestamp:properties.timestamp}" --output table
  
  # Check resource groups
  log_info "Existing resource groups (filtered for secure-secret-sharer):"
  az group list --query "[?contains(name, 'ssharer') || contains(name, 'secure-secret')].{Name:name,State:properties.provisioningState,Location:location}" --output table
  
  # Check quotas for common resources
  log_info "Subscription quota information:"
  az vm list-usage --location "spaincentral" --query "[?contains(name.value, 'cores') || contains(name.value, 'Core')].{Resource:name.localizedValue,Current:currentValue,Limit:limit}" --output table
  
  echo "✅ Diagnostics completed."
}

# =====================================================
# Main Script Logic
# =====================================================

# Default environment
ENVIRONMENT="dev"

# Parse arguments
ACTION=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      ENVIRONMENT="$2"
      if [[ "$ENVIRONMENT" != "dev" && "$ENVIRONMENT" != "prod" ]]; then
        echo "Error: Environment must be 'dev' or 'prod'"
        exit 1
      fi
      shift 2 ;;
    shared|k8s|paas|all|teardown|diagnostics)
      if [[ -z "$ACTION" ]]; then
        ACTION="$1"
        shift
      else
        echo "Error: Multiple actions specified"
        exit 1
      fi ;;
    *)
      echo "Unknown option: $1"
      exit 1 ;;
  esac
done

# Update parameter file paths based on environment
SHARED_PARAMS_FILE="../infra/0-landing-zone/swa.${ENVIRONMENT}.bicepparam"
K8S_PARAMS_FILE="../infra/0-landing-zone/aks.${ENVIRONMENT}.bicepparam"
PAAS_PARAMS_FILE="../infra/0-landing-zone/swa.${ENVIRONMENT}.bicepparam"

echo "Using environment: $ENVIRONMENT"

# Display usage information if no action is provided
if [ -z "$ACTION" ]; then
  echo "❌ Error: No action specified"
  echo ""
  echo "Usage: $0 [ACTION] [--env dev|prod]"
  echo ""
  echo "Available Actions:"
  echo "  teardown     - Delete all landing zone resource groups"
  echo "  shared       - Deploy only shared infrastructure"
  echo "  k8s          - Deploy shared + K8S landing zone"
  echo "  paas         - Deploy shared + PaaS landing zone"
  echo "  all          - Deploy everything (shared + K8S + PaaS)"
  echo "  diagnostics  - Run comprehensive diagnostics for troubleshooting"
  echo ""
  echo "Options:"
  echo "  --env dev|prod - Deployment environment (default: dev)"
  echo ""
  echo "Examples:"
  echo "  $0 shared                    # Deploy shared infrastructure only (dev)"
  echo "  $0 k8s --env prod           # Deploy for Kubernetes workloads (prod)"
  echo "  $0 paas --env dev           # Deploy for PaaS workloads (dev)"
  echo "  $0 all                      # Deploy complete landing zone (dev)"
  echo "  $0 teardown                 # Clean up all resources"
  echo "  $0 diagnostics              # Troubleshoot deployment issues"
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

# Check for recent failed deployments and show quick info
echo "🔍 Checking for recent failed deployments..."
RECENT_FAILED=$(az deployment sub list --query "[?properties.provisioningState=='Failed'] | [0].name" --output tsv 2>/dev/null)
if [ -n "$RECENT_FAILED" ] && [ "$RECENT_FAILED" != "null" ]; then
  echo "⚠️  Recent failed deployment found: $RECENT_FAILED"
  echo "   Use './deploy-landing-zone.sh diagnostics' for detailed analysis"
else
  echo "✅ No recent failed deployments found"
fi
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
    echo "🚀 Proceeding with shared infrastructure deployment (non-interactive mode)..."
    
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
    echo "🚀 Proceeding with shared + K8S deployments (non-interactive mode)..."
    
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
    
    # Show what-if analysis for PaaS only (shared is included)
    show_whatif "$PAAS_DEPLOYMENT_NAME" "$PAAS_BICEP_FILE" "$PAAS_PARAMS_FILE" "PaaS Landing Zone"
    
    echo ""
    echo "📋 This will deploy PaaS landing zone infrastructure"
    echo "🚀 Proceeding with PaaS deployment (non-interactive mode)..."
    
    deploy_paas
    ;;
  all)
    deploy_all
    ;;
  diagnostics)
    echo "🔍 Running comprehensive diagnostics..."
    echo "   This will check Azure CLI, authentication, providers, and recent deployments"
    echo ""
    run_diagnostics
    ;;
  *)
    echo "❌ Unknown action: $ACTION"
    echo ""
    echo "Valid actions: teardown, shared, k8s, paas, all, diagnostics"
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
echo ""
echo "💡 For troubleshooting: ./deploy-landing-zone.sh diagnostics"

exit 0
