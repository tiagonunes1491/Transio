#!/bin/bash
# filepath: c:\Users\tiagonunes\OneDrive - Microsoft\secure-secret-sharer\scripts\deploy-landing-zone.sh
#
# Script to deploy complete landing zone infrastructure with workload UAMIs
# This script deploys the landing-zone.bicep with all components in a single deployment

set -e  # Exit on any error

# Configuration
DEPLOYMENT_NAME="landing-zone-full-$(date +%Y%m%d-%H%M%S)"
BICEP_FILE="../infra/landing-zone.bicep"
PARAMS_FILE="../infra/landing-zone.dev.bicepparam"
SUBSCRIPTION_SCOPE="subscription"

echo "🚀 Starting Complete Landing Zone Infrastructure Deployment..."
echo "Deployment Name: $DEPLOYMENT_NAME"
echo "Bicep File: $BICEP_FILE"
echo "Parameters File: $PARAMS_FILE"
echo ""

# Validate that required files exist
if [ ! -f "$BICEP_FILE" ]; then
    echo "❌ Error: Bicep file not found at $BICEP_FILE"
    exit 1
fi

if [ ! -f "$PARAMS_FILE" ]; then
    echo "❌ Error: Parameters file not found at $PARAMS_FILE"
    exit 1
fi

# Ensure user is logged into Azure
echo "🔐 Checking Azure authentication..."
if ! az account show &> /dev/null; then
    echo "❌ Not logged into Azure. Please run 'az login' first."
    exit 1
fi

# Get current subscription info
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
echo "✅ Authenticated to subscription: $SUBSCRIPTION_NAME ($SUBSCRIPTION_ID)"
echo ""

# Validate deployment with what-if
echo "🔍 Validating complete landing zone deployment with what-if analysis..."
az deployment sub what-if \
    --name "$DEPLOYMENT_NAME" \
    --location "spaincentral" \
    --template-file "$BICEP_FILE" \
    --parameters "$PARAMS_FILE"

echo ""
read -p "Do you want to proceed with the complete landing zone deployment? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Deployment cancelled by user."
    exit 0
fi

# Deploy the infrastructure
echo "🛠️  Deploying complete landing zone infrastructure..."
DEPLOYMENT_OUTPUT=$(az deployment sub create \
    --name "$DEPLOYMENT_NAME" \
    --location "spaincentral" \
    --template-file "$BICEP_FILE" \
    --parameters "$PARAMS_FILE" \
    --output json)

if [ $? -ne 0 ]; then
    echo "❌ Deployment failed!"
    exit 1
fi

echo "✅ Complete landing zone deployment completed successfully!"
echo ""

# Extract outputs from deployment
echo "📋 Extracting deployment outputs..."
MANAGEMENT_RG_NAME=$(az deployment sub show --name "$DEPLOYMENT_NAME" --query 'properties.outputs.managementResourceGroupName.value' -o tsv)
HUB_RG_NAME=$(az deployment sub show --name "$DEPLOYMENT_NAME" --query 'properties.outputs.hubResourceGroupName.value' -o tsv)
K8S_RG_NAME=$(az deployment sub show --name "$DEPLOYMENT_NAME" --query 'properties.outputs.k8sResourceGroupName.value' -o tsv)
PAAS_RG_NAME=$(az deployment sub show --name "$DEPLOYMENT_NAME" --query 'properties.outputs.paasResourceGroupName.value' -o tsv)
TENANT_ID=$(az deployment sub show --name "$DEPLOYMENT_NAME" --query 'properties.outputs.tenantId.value' -o tsv)
ENVIRONMENT_NAME=$(az deployment sub show --name "$DEPLOYMENT_NAME" --query 'properties.outputs.environmentName.value' -o tsv)

# Extract UAMI information
ACR_UAMI_NAME=$(az deployment sub show --name "$DEPLOYMENT_NAME" --query 'properties.outputs.acrUamiName.value' -o tsv)
ACR_UAMI_CLIENT_ID=$(az deployment sub show --name "$DEPLOYMENT_NAME" --query 'properties.outputs.acrUamiClientId.value' -o tsv)
K8S_UAMI_NAME=$(az deployment sub show --name "$DEPLOYMENT_NAME" --query 'properties.outputs.k8sUamiName.value' -o tsv)
K8S_UAMI_CLIENT_ID=$(az deployment sub show --name "$DEPLOYMENT_NAME" --query 'properties.outputs.k8sUamiClientId.value' -o tsv)
K8S_DEPLOY_UAMI_NAME=$(az deployment sub show --name "$DEPLOYMENT_NAME" --query 'properties.outputs.k8sDeployUamiName.value' -o tsv)
K8S_DEPLOY_UAMI_CLIENT_ID=$(az deployment sub show --name "$DEPLOYMENT_NAME" --query 'properties.outputs.k8sDeployUamiClientId.value' -o tsv)
PAAS_UAMI_NAME=$(az deployment sub show --name "$DEPLOYMENT_NAME" --query 'properties.outputs.paasUamiName.value' -o tsv)
PAAS_UAMI_CLIENT_ID=$(az deployment sub show --name "$DEPLOYMENT_NAME" --query 'properties.outputs.paasUamiClientId.value' -o tsv)

echo ""
echo "📋 Resource Groups Created:"
echo "  ✅ Management RG: $MANAGEMENT_RG_NAME"
echo "  ✅ Hub RG: $HUB_RG_NAME"
echo "  ✅ K8s Spoke RG: $K8S_RG_NAME"
echo "  ✅ PaaS Spoke RG: $PAAS_RG_NAME"
echo ""
echo "📋 UAMIs Created:"
echo "  ✅ ACR UAMI: $ACR_UAMI_NAME (Client ID: $ACR_UAMI_CLIENT_ID)"
echo "  ✅ K8s UAMI: $K8S_UAMI_NAME (Client ID: $K8S_UAMI_CLIENT_ID)"
echo "  ✅ K8s Deploy UAMI: $K8S_DEPLOY_UAMI_NAME (Client ID: $K8S_DEPLOY_UAMI_CLIENT_ID)"
echo "  ✅ PaaS UAMI: $PAAS_UAMI_NAME (Client ID: $PAAS_UAMI_CLIENT_ID)"
echo ""
echo "Environment: $ENVIRONMENT_NAME"
echo "Tenant ID: $TENANT_ID"
echo ""

# Summary
echo "✅ Complete Landing Zone Deployment Summary:"
echo "  └─ Deployment Name: $DEPLOYMENT_NAME"
echo "  └─ Environment: $ENVIRONMENT_NAME"
echo "  └─ Subscription: $SUBSCRIPTION_NAME ($SUBSCRIPTION_ID)"
echo "  └─ Tenant: $TENANT_ID"
echo ""
echo "📋 Resource Groups Created:"
echo "  ✅ $MANAGEMENT_RG_NAME (Management)"
echo "  ✅ $HUB_RG_NAME (Shared Artifacts Hub)"
echo "  ✅ $K8S_RG_NAME (Kubernetes Spoke)"
echo "  ✅ $PAAS_RG_NAME (PaaS Spoke)"
echo ""
echo "📋 UAMIs Created & Federated:"
echo "  ✅ $ACR_UAMI_NAME (ACR Push permissions)"
echo "  ✅ $K8S_UAMI_NAME (K8s Contributor + ACR Pull)"
echo "  ✅ $K8S_DEPLOY_UAMI_NAME (ACR Pull for deployments)"
echo "  ✅ $PAAS_UAMI_NAME (PaaS Contributor + ACR Pull)"
echo ""
echo "🎉 Complete landing zone deployment completed!"
echo ""
echo "📋 Next Steps:"
echo "1. Deploy workload-specific infrastructure (ACR, AKS, Container Apps, etc.)"
echo "2. Configure GitHub Actions workflows to use the federated identities"
echo "3. Test deployments to each spoke environment"
