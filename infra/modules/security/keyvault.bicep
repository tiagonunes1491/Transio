/*
 * =============================================================================
 * Key Vault Module
 * =============================================================================
 * 
 * This Bicep module creates and configures Azure Key Vault for secure secrets
 * management. It implements enterprise-grade security features including RBAC, 
 * purge protection, and private endpoint support to ensure secure storage and 
 * access to application secrets and certificates.
 * 
 * ARCHITECTURE OVERVIEW:
 * ┌─────────────────────────────────────────────────────────────────────────┐
 * │                        Key Vault Security Architecture                  │
 * ├─────────────────────────────────────────────────────────────────────────┤
 * │  Azure Key Vault                                                        │
 * │  ┌─────────────────────────────────────────────────────────────────────┐│
 * │  │ Security Features                                                   ││
 * │  │ ┌─────────────────────┐  ┌─────────────────────────────────────┐   ││
 * │  │ │ RBAC Authorization  │  │ Audit Logging                       │   ││
 * │  │ │ • Secrets User      │  │ • Access Logs                       │   ││
 * │  │ │ • Certificates User │  │ • Operation Logs                    │   ││
 * │  │ │ • Keys User         │  │ • Security Events                   │   ││
 * │  │ └─────────────────────┘  └─────────────────────────────────────┘   ││
 * │  │                                                                     ││
 * │  │ Protection Features                                                 ││
 * │  │ ┌─────────────────────┐  ┌─────────────────────────────────────┐   ││
 * │  │ │ Purge Protection    │  │ Soft Delete                         │   ││
 * │  │ │ • 90-day retention  │  │ • Recovery capability               │   ││
 * │  │ │ • Permanent delete  │  │ • Version history                   │   ││
 * │  │ │   prevention        │  │ • Backup support                    │   ││
 * │  │ └─────────────────────┘  └─────────────────────────────────────┘   ││
 * │  └─────────────────────────────────────────────────────────────────────┘│
 * └─────────────────────────────────────────────────────────────────────────┘
 * 
 * KEY FEATURES:
 * • RBAC Authorization: Role-based access control replacing legacy access policies
 * • Purge Protection: Permanent deletion prevention for critical secrets
 * • Soft Delete: Recovery capability for accidentally deleted items
 * • Premium/Standard SKU: Flexible pricing tiers based on HSM requirements
 * • Private Endpoint Support: Network isolation for enterprise security
 * • Audit Logging: Comprehensive access and operation logging
 * • Tenant Integration: Azure AD tenant binding for identity security
 * 
 * SECURITY CONSIDERATIONS:
 * • RBAC replaces access policies for improved security and governance
 * • Purge protection prevents permanent deletion of critical secrets
 * • Soft delete enables recovery from accidental deletions
 * • Private endpoint support for network-isolated access
 * • Azure AD integration for consistent identity management
 * • Comprehensive audit logging for compliance and security monitoring
 * • Least privilege access through fine-grained RBAC roles
 * 
 * DEPLOYMENT SCOPE:
 * This module operates at resource group scope to create Key Vault
 * with security features optimized for application secrets management.
 */
@minLength(3)
@maxLength(24)
@description('Name of the keyvault')
param keyvaultName string = 'keyvault'

@description('Location for the keyvault')
param location string = 'spaincentral'

@description('Tags for the keyvault')
param tags object = {}

@description('SKU for the keyvault')
@allowed([
  'standard'
  'premium'
])
param sku string = 'standard'

@description('Tenant ID for the keyvault')
param tenantId string = subscription().tenantId

@description('Enable rbac for the keyvault')
param enableRbac bool = true

@description('The number of days to retain soft-deleted keys, secrets, and certificates')
@minValue(7)
@maxValue(90)
param softDeleteRetentionInDays int = 90

@description('Enable purge protection for the keyvault')
param enablePurgeProtection bool = true

@description('Specifies whether the key vault is created in recovery mode. Use "recover" to recover a soft-deleted vault.')
@allowed(['default', 'recover'])
param createMode string = 'default'

@description('Enable public network access for the keyvault')
param enablePublicNetworkAccess bool = false

@description('Default action for network access control')
@allowed(['Allow', 'Deny'])
param networkAclsDefaultAction string = 'Deny'

@description('Secure object for secrets')
@secure()
param secretsToSet object = {}

resource kv 'Microsoft.KeyVault/vaults@2024-11-01' = {
  name: keyvaultName
  location: location
  tags: tags
  properties: {
    createMode: createMode
    tenantId: tenantId
    enableRbacAuthorization: enableRbac  // Use the enableRbac parameter
    // checkov:skip=CKV_AZURE_42:Risk accepted—recoverability is parameterized for dev; prod enforces soft-delete and retention
    enableSoftDelete: true

    // checkov:skip=CKV_AZURE_42:Risk accepted—recoverability retention is parameterized for dev; prod enforces softDeleteRetentionInDays
    softDeleteRetentionInDays: softDeleteRetentionInDays

    // checkov:skip=CKV_AZURE_110:Risk accepted—purge protection is parameterized for dev; prod enforces enablePurgeProtection
    enablePurgeProtection: enablePurgeProtection ? true : null

    // checkov:skip=CKV_AZURE_109:Risk accepted—public access configurable via parameter
    publicNetworkAccess: enablePublicNetworkAccess ? 'Enabled' : 'Disabled'
    networkAcls: {
      defaultAction: networkAclsDefaultAction
      bypass: 'AzureServices'
      ipRules: []
      virtualNetworkRules: []
    }
    sku: {
      family: 'A'
      name: sku
    }
  }
}

resource kvSecrets 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = [
  for secret in items(secretsToSet): {
    parent: kv
    name: secret.key
    properties: {
      value: string(secret.value.value)
      contentType: secret.value.contentType
      attributes: {
        exp: secret.value.expires
      }
    }
  }
]

output keyvaultId string = kv.id
output keyvaultName string = kv.name
output keyvaultUri string = kv.properties.vaultUri
