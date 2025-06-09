#!/bin/bash
# filepath: c:\Users\tiagonunes\OneDrive - Microsoft\secure-secret-sharer\scripts\github-bootstrap.sh
#
# Script to deploy GitHub bootstrap infrastructure
# This script deploys the github-bootstrap.bicep with dev parameters

set -e  # Exit on any error

# Configuration
DEPLOYMENT_NAME="github-bootstrap-dev-$(date +%Y%m%d-%H%M%S)"
BICEP_FILE="../infra/github-bootstrap.bicep"
PARAMS_FILE="../infra/github-bootstrap.dev.bicepparam"
SUBSCRIPTION_SCOPE="subscription"

echo "🚀 Starting GitHub Bootstrap Infrastructure Deployment..."
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
echo "🔍 Validating deployment with what-if analysis..."
az deployment sub what-if \
    --name "$DEPLOYMENT_NAME" \
    --location "spaincentral" \
    --template-file "$BICEP_FILE" \
    --parameters "$PARAMS_FILE"

echo ""
read -p "Do you want to proceed with the deployment? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Deployment cancelled by user."
    exit 0
fi

# Deploy the infrastructure
echo "🛠️  Deploying GitHub bootstrap infrastructure..."
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

echo "✅ Infrastructure deployment completed successfully!"
echo ""

# Extract outputs from deployment
echo "📋 Extracting deployment outputs..."
UAMI_PRINCIPAL_ID=$(az deployment sub show --name "$DEPLOYMENT_NAME" --query 'properties.outputs.uamiPrincipalId.value' -o tsv)
RESOURCE_GROUP_NAME=$(az deployment sub show --name "$DEPLOYMENT_NAME" --query 'properties.outputs.resourceGroupName.value' -o tsv)
TENANT_ID=$(az deployment sub show --name "$DEPLOYMENT_NAME" --query 'properties.outputs.tenantId.value' -o tsv)
SECURITY_GROUP_ID=$(az deployment sub show --name "$DEPLOYMENT_NAME" --query 'properties.outputs.securityGroupId.value' -o tsv)
SECURITY_GROUP_NAME=$(az deployment sub show --name "$DEPLOYMENT_NAME" --query 'properties.outputs.securityGroupName.value' -o tsv)

echo "UAMI Principal ID: $UAMI_PRINCIPAL_ID"
echo "Resource Group: $RESOURCE_GROUP_NAME"
echo "Tenant ID: $TENANT_ID"
echo "Security Group ID: $SECURITY_GROUP_ID"
echo "Security Group Name: $SECURITY_GROUP_NAME"
echo ""

# Summary
echo "✅ GitHub Bootstrap Deployment Summary:"
echo "  └─ Deployment Name: $DEPLOYMENT_NAME"
echo "  └─ UAMI Principal ID: $UAMI_PRINCIPAL_ID"
echo "  └─ Resource Group: $RESOURCE_GROUP_NAME"
echo "  └─ Subscription: $SUBSCRIPTION_NAME ($SUBSCRIPTION_ID)"
echo "  └─ Tenant: $TENANT_ID"
echo "  └─ Security Group: $SECURITY_GROUP_NAME ($SECURITY_GROUP_ID)"
echo ""
echo "🎉 Deployment completed!"
echo ""
echo "📋 Next Steps:"
echo "1. Configure PIM settings manually in Azure Portal: https://portal.azure.com/#blade/Microsoft_Azure_PIMCommon/CommonMenuBlade/quickStart"
echo "2. Test GitHub Actions workflows with the federated identity"
