# Bootstrap Key Vault Deployment

This directory contains the bootstrap Key Vault deployment for the Transio application. Each platform and environment combination gets its own dedicated Key Vault that must be deployed before the corresponding platform infrastructure.

## Purpose

The bootstrap Key Vault serves as the platform-specific secrets management solution for each environment. It provides:

- **Platform-Specific Secret Management**: Dedicated Key Vault per platform and environment
- **Environment Isolation**: Complete separation between dev/prod and AKS/SWA environments  
- **Security**: Enterprise-grade security features including RBAC and purge protection
- **Network Security**: Support for private endpoint connectivity from platform

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     Bootstrap Key Vault Infrastructure                  │
├─────────────────────────────────────────────────────────────────────────┤
│  Centralized Key Vault                                                  │
│  ┌─────────────────────────────────────────────────────────────────────┐│
│  │ Security Features                                                   ││
│  │ ┌─────────────────────┐  ┌─────────────────────────────────────┐   ││
│  │ │ RBAC Authorization  │  │ Protection Features                 │   ││
│  │ │ • Platform Access   │  │ • Purge Protection                  │   ││
│  │ │ • Service Identity  │  │ • Soft Delete                       │   ││
│  │ │ • Admin Access      │  │ • 90-day retention                  │   ││
│  │ └─────────────────────┘  └─────────────────────────────────────┘   ││
│  │                                                                     ││
│  │ Shared Access                                                       ││
│  │ ┌─────────────────────┐  ┌─────────────────────────────────────┐   ││
│  │ │ AKS Platform        │  │ SWA/ACA Platform                    │   ││
│  │ │ • Backend secrets   │  │ • API secrets                       │   ││
│  │ │ • K8s integration   │  │ • Container Apps config             │   ││
│  │ │ • UAMI access       │  │ • Private endpoint access           │   ││
│  │ └─────────────────────┘  └─────────────────────────────────────┘   ││
│  └─────────────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────────┘
```

## Deployment Order

The bootstrap Key Vault must be deployed in the following order for each platform:

1. **Bootstrap Key Vault** (this deployment) - `infra/10-bootstrap-kv/`
   - Deploy for SWA: `swa.dev.bicepparam` → creates `ts-dev-swa-kv`
   - Deploy for AKS: `aks.dev.bicepparam` → creates `ts-dev-aks-kv`
2. **Secret Management** - Configure secrets in each Key Vault externally
3. **Platform Infrastructure** - Deploy platform referencing its Key Vault:
   - AKS Platform - `infra/20-platform-aks/` → references `ts-dev-aks-kv`
   - SWA/ACA Platform - `infra/20-platform-swa/` → references `ts-dev-swa-kv`
4. **Workload Deployments** - `infra/30-workload-*/`

## Deployment Commands

### Prerequisites

Ensure you have the following tools installed:
- Azure CLI (`az`)
- Bicep CLI

### Deploy Bootstrap Key Vault

Deploy for each platform separately:

#### SWA Platform Key Vault

```powershell
# Set variables for SWA deployment
$resourceGroupName = "rg-ts-dev-swa"
$subscriptionId = "your-subscription-id"
$location = "spaincentral"

# Create resource group if it doesn't exist
az group create --name $resourceGroupName --location $location --subscription $subscriptionId

# Deploy the SWA Key Vault
az deployment group create `
  --resource-group $resourceGroupName `
  --template-file main.bicep `
  --parameters swa.dev.bicepparam `
  --subscription $subscriptionId
```

#### AKS Platform Key Vault

```powershell
# Set variables for AKS deployment
$resourceGroupName = "rg-ts-dev-aks"
$subscriptionId = "your-subscription-id"
$location = "spaincentral"

# Create resource group if it doesn't exist
az group create --name $resourceGroupName --location $location --subscription $subscriptionId

# Deploy the AKS Key Vault
az deployment group create `
  --resource-group $resourceGroupName `
  --template-file main.bicep `
  --parameters aks.dev.bicepparam `
  --subscription $subscriptionId
```

### Configure Secrets

After Key Vault deployment, configure secrets externally:

```powershell
# Configure SWA secrets
az keyvault secret set --vault-name "ts-dev-swa-kv" --name "cosmos-endpoint" --value "https://..."
az keyvault secret set --vault-name "ts-dev-swa-kv" --name "encryption-key" --value "base64-key"

# Configure AKS secrets  
az keyvault secret set --vault-name "ts-dev-aks-kv" --name "cosmos-endpoint" --value "https://..."
az keyvault secret set --vault-name "ts-dev-aks-kv" --name "encryption-key" --value "base64-key"
```

### Verify Deployment

```powershell
# Get SWA Key Vault details
az keyvault show --name "ts-dev-swa-kv" --resource-group "rg-ts-dev-swa"

# Get AKS Key Vault details
az keyvault show --name "ts-dev-aks-kv" --resource-group "rg-ts-dev-aks"

# List Key Vault properties for platform configurations
az deployment group show `
  --name "main" `
  --resource-group $resourceGroupName `
  --query "properties.outputs"
```

## Configuration

### Parameters

The deployment uses the following key parameters:

- `projectCode`: Project identifier (default: `ss`)
- `serviceCode`: Service identifier (specify `swa` or `aks` for platform-specific deployment)
- `environmentName`: Environment name (default: `dev`)
- `resourceLocation`: Azure region (default: `spaincentral`)
- `kvSku`: Key Vault SKU (default: `standard`)
- `kvRbac`: Enable RBAC (default: `true`)
- `kvPurgeProtection`: Enable purge protection (default: `true`)

### Resource Naming Convention

Resources follow the naming pattern: `{projectCode}-{environment}-{serviceCode}-{resourceType}`

Example: `ts-dev-swa-kv`, `ts-dev-aks-kv`

## Security Features

### RBAC Authorization
- Role-based access control replaces legacy access policies
- Platform managed identities granted appropriate access
- Fine-grained permissions for different service types

### Protection Features
- **Purge Protection**: Prevents permanent deletion of the Key Vault
- **Soft Delete**: 90-day retention for recovery capability
- **Network Security**: Support for private endpoint connectivity

### Access Patterns
- Platform services access via managed identity
- Secrets managed externally (not created during deployment)
- RBAC assignments handled by platform deployments

## Outputs

The deployment provides the following outputs for platform reference:

- `keyVaultName`: Resource name for platform deployments
- `keyVaultId`: Resource ID for RBAC assignments and private endpoints
- `keyVaultUri`: URI for application configuration
- `tenantId`: Azure AD tenant ID for federated credentials
- `resourceGroupName`: Resource group name
- `keyVaultLocation`: Location for private endpoint planning

## Secret Management

### External Secret Management
Secrets are **not** created during the bootstrap deployment. They should be managed externally using:

- Azure CLI: `az keyvault secret set`
- Azure Portal: Key Vault secrets section
- Azure DevOps: Variable groups with Key Vault integration
- GitHub Actions: Secrets and variables

### Example Secret Management

```powershell
# Set application secrets
az keyvault secret set --vault-name "ts-dev-bootstrap-kv" --name "cosmos-endpoint" --value "https://..."
az keyvault secret set --vault-name "ts-dev-bootstrap-kv" --name "encryption-key" --value "base64-encoded-key"
az keyvault secret set --vault-name "ts-dev-bootstrap-kv" --name "cosmos-database-name" --value "ssdb"
az keyvault secret set --vault-name "ts-dev-bootstrap-kv" --name "cosmos-container-name" --value "secrets"

# SWA deployment token (automatically managed by GitHub Actions)
az keyvault secret set --vault-name "ts-dev-bootstrap-kv" --name "SWA-DEPLOYMENT-TOKEN" --value "swa-token-value"
```

### Automated Secret Management

#### SWA Deployment Token Rotation
The **SWA deployment token** is automatically managed via GitHub Actions:

- **Secret Name**: `SWA-DEPLOYMENT-TOKEN`
- **Storage**: Azure Key Vault (environment-specific)
- **Rotation**: Monthly automated rotation (1st day of month at 02:00 UTC)
- **Workflow**: `cd-rotate-deployment-token.yml`
- **Manual Trigger**: Available via GitHub Actions workflow dispatch
- **Security**: Uses separate federated identities for token generation and Key Vault access

#### Fernet Encryption Keys
Application encryption keys are automatically generated and rotated:

- **Secret Name**: `encryption-key` 
- **Generation**: Via `cd-infra-rotate-key.yml` workflow
- **Trigger**: Automatic (after Key Vault deployment) or manual dispatch
- **Rotation**: On-demand via GitHub Actions

## Platform Integration

### AKS Platform Integration
The AKS platform (`infra/20-platform-aks/`) references this Key Vault via:
- Parameter: `existingKeyVaultName`
- Parameter: `existingKeyVaultResourceGroup`
- RBAC assignments for managed identities
- Private endpoint connectivity

### SWA/ACA Platform Integration
The SWA/ACA platform (`infra/20-platform-swa/`) references this Key Vault via:
- Parameter: `existingKeyVaultName`
- Parameter: `existingKeyVaultResourceGroup`
- Private endpoint connectivity for Container Apps

## Troubleshooting

### Common Issues

1. **Resource Group Doesn't Exist**
   ```powershell
   az group create --name "rg-ts-dev-bootstrap" --location "spaincentral"
   ```

2. **Insufficient Permissions**
   Ensure your account has `Contributor` role on the target resource group and subscription.

3. **Key Vault Name Conflicts**
   Key Vault names must be globally unique. Modify the `serviceCode` parameter if needed.

4. **Purge Protection Issues**
   Once enabled, purge protection cannot be disabled. Plan carefully for development environments.

### Validation Commands

```powershell
# Check deployment status
az deployment group list --resource-group "rg-ts-dev-bootstrap"

# Validate Key Vault configuration
az keyvault show --name "ts-dev-bootstrap-kv" --query "{name:name,sku:properties.sku.name,rbac:properties.enableRbacAuthorization,purgeProtection:properties.enablePurgeProtection}"

# Test Key Vault connectivity
az keyvault secret list --vault-name "ts-dev-bootstrap-kv"
```

## Next Steps

After successful deployment:

1. Configure application secrets in the Key Vault
2. Deploy platform infrastructure (AKS or SWA/ACA)
3. Verify platform services can access the Key Vault
4. Deploy workload applications
