
/*
 * =============================================================================
 * Bootstrap Key Vault for Transio
 * =============================================================================
 * 
 * This Bicep template creates a platform-specific Azure Key Vault for the 
 * Transio application. Each platform deployment (AKS, SWA/ACA) 
 * and environment (dev, prod) gets its own dedicated Key Vault created during 
 * the bootstrap phase, before platform infrastructure deployment.
 * 
 * ARCHITECTURE OVERVIEW:
 * ┌─────────────────────────────────────────────────────────────────────────┐
 * │                   Platform-Specific Key Vault Infrastructure            │
 * ├─────────────────────────────────────────────────────────────────────────┤
 * │  Platform Key Vault (per platform + environment)                       │
 * │  ┌─────────────────────────────────────────────────────────────────────┐│
 * │  │ Security Features                                                   ││
 * │  │ ┌─────────────────────┐  ┌─────────────────────────────────────┐   ││
 * │  │ │ RBAC Authorization  │  │ Protection Features                 │   ││
 * │  │ │ • Platform Access   │  │ • Purge Protection                  │   ││
 * │  │ │ • Service Identity  │  │ • Soft Delete                       │   ││
 * │  │ │ • Admin Access      │  │ • 90-day retention                  │   ││
 * │  │ └─────────────────────┘  └─────────────────────────────────────┘   ││
 * │  │                                                                     ││
 * │  │ Platform-Specific Access                                            ││
 * │  │ ┌─────────────────────────────────────────────────────────────────┐ ││
 * │  │ │ Dedicated to Single Platform + Environment                      │ ││
 * │  │ │ • ss-dev-swa-kv    (SWA Dev environment)                       │ ││
 * │  │ │ • ss-prod-swa-kv   (SWA Prod environment)                      │ ││
 * │  │ │ • ss-dev-aks-kv    (AKS Dev environment)                       │ ││
 * │  │ │ • ss-prod-aks-kv   (AKS Prod environment)                      │ ││
 * │  │ └─────────────────────────────────────────────────────────────────┘ ││
 * │  └─────────────────────────────────────────────────────────────────────┘│
 * └─────────────────────────────────────────────────────────────────────────┘
 * 
 * DEPLOYMENT STRATEGY:
 * • Bootstrap First: Deploy Key Vault before platform infrastructure
 * • Platform-Specific: Each platform + environment combination gets its own Key Vault
 * • Secret Management: No secrets created during deployment - handled in separate step
 * • Access Control: RBAC-based access for platform managed identities
 * • Network Security: SECURE BY DEFAULT - private endpoint only, public access disabled
 * • Development Override: Public access can be explicitly enabled via parameters for dev environments
 * 
 * SECURITY DEFAULTS:
 * • Public Network Access: DISABLED by default
 * • Network ACLs: DENY all by default (private endpoint access only)
 * • RBAC Authorization: ENABLED by default
 * • Purge Protection: ENABLED by default
 * • Soft Delete: ENABLED by default (90-day retention)
 * 
 * USAGE PATTERN:
 * 1. Deploy this bootstrap Key Vault for specific platform + environment
 * 2. Manage secrets externally through Azure CLI, Portal, or automation
 * 3. Deploy platform infrastructure referencing this Key Vault
 * 4. Platform services access secrets via managed identity and RBAC
 */



targetScope = 'resourceGroup'

/*
 * =============================================================================
 * PARAMETERS
 * =============================================================================
 */

// ========== CORE DEPLOYMENT PARAMETERS ==========

@description('Azure AD tenant ID for Key Vault authentication and managed identity federation')
param tenantId string = subscription().tenantId

@description('Azure region for Key Vault deployment')
param resourceLocation string = 'spaincentral'

@description('Short project identifier used in resource naming conventions')
param projectCode string = 'ts'

@description('Service identifier for this platform-specific Key Vault deployment (e.g., swa, aks)')
param serviceCode string

@description('Target environment for deployment affecting resource configuration and naming')
@allowed(['dev', 'prod'])
param environmentName string = 'dev'

// ========== GOVERNANCE AND TAGGING PARAMETERS ==========

@description('Cost center identifier for billing allocation and financial tracking')
param costCenter string = '1000'

@description('Deployment method identifier for tracking automation sources')
param createdBy string = 'bicep-deployment'

@description('Resource owner identifier for accountability and governance')
param owner string 

@description('Resource owner email for notifications and governance contacts')
param ownerEmail string

// ========== KEY VAULT CONFIGURATION PARAMETERS ==========

@description('Key Vault SKU tier - standard or premium')
@allowed([ 'standard', 'premium' ])
param kvSku string = 'standard'

@description('Enable RBAC on Key Vault for access control')
param kvRbac bool = true

@description('Enable purge protection on Key Vault for security')
param kvPurgeProtection bool = true

@description('Enable public network access for Key Vault - SECURE BY DEFAULT: disabled for production security')
param kvEnablePublicNetworkAccess bool = false

@description('Default action for Key Vault network access control - SECURE BY DEFAULT: deny all except private endpoints')
@allowed(['Allow', 'Deny'])
param kvNetworkAclsDefaultAction string = 'Deny'

@description('Set to true to recover a soft-deleted Key Vault instead of creating a new one. This should be a one-time operation.')
param recoverExistingVault bool = false

/*
 * =============================================================================
 * RESOURCE NAMING AND TAGGING MODULES
 * =============================================================================
 */

// ========== STANDARDIZED TAGGING ==========

module standardTagsModule '../modules/shared/tagging.bicep' = {
  name: 'standard-tags-bootstrap-kv'
  params: {
    environment: environmentName
    project: projectCode
    service: serviceCode
    costCenter: costCenter
    createdBy: createdBy
    owner: owner
    ownerEmail: ownerEmail
  }
}

// ========== RESOURCE NAMING ==========

module kvNamingModule '../modules/shared/naming.bicep' = {
  name: 'kv-naming'
  params: {
    projectCode: projectCode
    environment: environmentName
    serviceCode: serviceCode
    resourceType: 'kv'
  }
}

/*
 * =============================================================================
 * KEY VAULT DEPLOYMENT
 * =============================================================================
 */

// ========== BOOTSTRAP KEY VAULT DEPLOYMENT ==========

module kv '../modules/security/keyvault.bicep' = {
  name: 'bootstrap-keyvault'
  params: {
    keyvaultName:                kvNamingModule.outputs.resourceName
    location:                    resourceLocation
    sku:                         kvSku
    tenantId:                    tenantId
    createMode:                  recoverExistingVault ? 'recover' : 'default'
    enableRbac:                  kvRbac
    enablePurgeProtection:       kvPurgeProtection
    enablePublicNetworkAccess:   kvEnablePublicNetworkAccess
    networkAclsDefaultAction:    kvNetworkAclsDefaultAction
    secretsToSet:                {} // No secrets created during bootstrap deployment
    tags:                        standardTagsModule.outputs.tags
  }
}

/*
 * =============================================================================
 * OUTPUTS
 * =============================================================================
 */

// ========== KEY VAULT OUTPUTS ==========

@description('Key Vault resource name for platform deployments to reference')
output keyVaultName string = kv.outputs.keyvaultName

@description('Key Vault resource ID for RBAC assignments and private endpoint configuration')
output keyVaultId string = kv.outputs.keyvaultId

@description('Key Vault URI for application configuration and SDK connections')
output keyVaultUri string = kv.outputs.keyvaultUri

@description('Azure AD tenant ID for federated identity credential configuration')
output tenantId string = tenantId

@description('Resource group name where Key Vault is deployed')
output resourceGroupName string = resourceGroup().name

@description('Key Vault location for private endpoint subnet planning')
output keyVaultLocation string = resourceLocation
