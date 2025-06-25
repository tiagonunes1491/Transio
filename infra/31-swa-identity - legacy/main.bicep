/*
 * =============================================================================
 * SWA Identity Management Infrastructure for Secure Secret Sharer
 * =============================================================================
 * 
 * This Bicep template creates the identity management infrastructure specifically
 * for Static Web App deployments. It establishes user-assigned managed identities
 * with comprehensive role-based access control (RBAC) assignments to enable
 * secure, keyless authentication to Azure services.
 * 
 * ARCHITECTURE OVERVIEW:
 * ┌─────────────────────────────────────────────────────────────────────────┐
 * │                    SWA Identity Management                              │
 * ├─────────────────────────────────────────────────────────────────────────┤
 * │  Identity Resource Group                                                │
 * │  ┌─────────────────────────────────────────────────────────────────────┐│
 * │  │ User-Assigned Managed Identity (UAMI)                              ││
 * │  │ ┌─────────────────────┐                                           ││
 * │  │ │ GitHub Federation   │                                           ││
 * │  │ │ Credentials         │                                           ││
 * │  │ └─────────────────────┘                                           ││
 * │  │         │                                                          ││
 * │  │         │ RBAC Assignments                                         ││
 * │  │         ▼                                                          ││
 * │  │ ┌─────────────────────┐  ┌─────────────────────────────────────┐   ││
 * │  │ │ Shared Services     │  │ Platform Services                   │   ││
 * │  │ │ • ACR Pull         │  │ • Key Vault Secrets User           │   ││
 * │  │ │ • Cosmos DB User   │  │ • Resource Group Contributor       │   ││
 * │  │ └─────────────────────┘  └─────────────────────────────────────┘   ││
 * │  └─────────────────────────────────────────────────────────────────────┘│
 * └─────────────────────────────────────────────────────────────────────────┘
 * 
 * KEY FEATURES:
 * • Managed Identity Creation: User-assigned managed identity for SWA workloads
 * • GitHub Federation: Federated identity credentials for secure CI/CD
 * • Least Privilege RBAC: Minimal required permissions for operation
 * • Cross-Resource Access: Secure access to shared platform services
 * • Service-Specific Permissions: Tailored access controls for each service type
 * • Audit Trail: Comprehensive logging of identity operations
 * • Zero-Credential Authentication: Eliminates password and key management
 * 
 * SECURITY CONSIDERATIONS:
 * • Federated identity credentials prevent credential exposure in CI/CD
 * • Principle of least privilege with service-specific role assignments
 * • Cross-resource group permissions controlled through explicit RBAC
 * • Managed identity lifecycle tied to deployment automation
 * • Audit logging for all identity operations and access attempts
 * • Role assignments scoped to specific resources where possible
 * 
 * DEPLOYMENT SCOPE:
 * This template operates at resource group scope to create identity
 * resources and assign cross-resource group permissions to shared
 * services like ACR, Cosmos DB, and Key Vault.
 */
targetScope = 'resourceGroup'

/*
 * =============================================================================
 * PARAMETERS
 * =============================================================================
 */

// ========== CORE DEPLOYMENT PARAMETERS ==========

@description('Azure region for managed identity deployment')
param resourceLocation string = 'spaincentral'

@description('Short project identifier used in resource naming conventions')
param projectCode string = 'ss'

@description('Service identifier for this SWA identity deployment')
param serviceCode string = 'swa'

@description('Target environment affecting identity configuration and permissions')
@allowed(['dev', 'prod'])
param environmentName string = 'dev'

// ========== GOVERNANCE AND TAGGING PARAMETERS ==========

@description('Cost center identifier for billing allocation and financial tracking')
param costCenter string = '1000'

@description('Deployment method identifier for tracking automation sources')
param createdBy string = 'bicep-deployment'

@description('Resource owner identifier for accountability and governance')
param owner string = 'tiago-nunes'

@description('Resource owner email for notifications and governance contacts')
param ownerEmail string = 'tiago.nunes@example.com'

// ========== SHARED INFRASTRUCTURE REFERENCES ==========

@description('Name of resource group containing shared services (ACR and Cosmos DB)')
param sharedResourceGroupName string

@description('Name of resource group containing Key Vault for secrets access')
param keyVaultResourceGroupName string

@description('Name of existing Azure Container Registry for pull permissions')
param acrName string

@description('Name of existing Cosmos DB account for data access permissions')
param cosmosDbAccountName string

@description('Name of existing Key Vault for secrets management')
param keyVaultName string

@description('Cosmos DB database name for scoped RBAC assignment')
param cosmosDatabaseName string = 'swa-dev'

// Reference existing shared resources
resource sssplatacr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: acrName
  scope: resourceGroup(subscription().subscriptionId, sharedResourceGroupName)
}

resource sssplatcosmos 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' existing = {
  name: cosmosDbAccountName
  scope: resourceGroup(subscription().subscriptionId, sharedResourceGroupName)
}

// Reference existing Key Vault resource
resource akv 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: keyVaultName
  scope: resourceGroup(subscription().subscriptionId, keyVaultResourceGroupName)
}

// ========== NAMING AND TAGGING MODULES ==========

// Generate standardized tags using the tagging module
module standardTagsModule '../40-modules/core/tagging.bicep' = {
  scope: subscription()
  name: 'standard-tags-swa-identity'
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

// Generate resource names using naming module
module uamiNamingModule '../40-modules/core/naming.bicep' = {
  scope: subscription()
  name: 'uami-naming'
  params: {
    projectCode: projectCode
    environment: environmentName
    serviceCode: serviceCode
    resourceType: 'id'
    suffix: 'ca-backend'
  }
}

// ========== USER ASSIGNED MANAGED IDENTITY ==========
module uami '../40-modules/core/uami.bicep' = {
  name: 'uami'
  params: {
    uamiLocation: resourceLocation
    uamiNames: [uamiNamingModule.outputs.resourceName]
    tags: standardTagsModule.outputs.tags
  }
}

// ========== RBAC ASSIGNMENTS ==========

// Deploy ACR RBAC at the ACR scope
module acrRbac '../40-modules/core/rbacAcr.bicep' = {
  name: 'acrRbac'
  scope: resourceGroup(subscription().subscriptionId, sharedResourceGroupName)
  params: {
    registryId: sssplatacr.id
    principalId: uami.outputs.uamis[0].principalId
    roleDefinitionId: '7f951dda-4ed3-4680-a7ca-43fe172d538d' // AcrPull role
  }
}

// Deploy Key Vault RBAC at the Key Vault scope
module keyVaultRbac '../40-modules/core/rbacKv.bicep' = {
  name: 'keyVaultRbac'
  scope: resourceGroup(subscription().subscriptionId, keyVaultResourceGroupName)
  params: {
    keyVaultId: akv.id
    id: uami.outputs.uamis[0].principalId
    keyVaultSecretsUserRoleId: '4633458b-17de-408a-b874-0445c86b69e6' // Key Vault Secrets User role
  }
}


// Deploy Cosmos DB RBAC in the shared resource group
module cosmosRbac '../40-modules/core/rbacCosmos.bicep' = {
  name: 'cosmosRbac'
  scope: resourceGroup(sharedResourceGroupName)
  params: {
    accountName: sssplatcosmos.name
    principalId: uami.outputs.uamis[0].principalId
    roleDefinitionId: '00000000-0000-0000-0000-000000000002' // Cosmos DB Built-in Data Contributor role
    databaseName: cosmosDatabaseName
  }
}


// ========== OUTPUTS ==========
output uamiId string = uami.outputs.uamis[0].id
output uamiClientId string = uami.outputs.uamis[0].clientId
output uamiPrincipalId string = uami.outputs.uamis[0].principalId
output uamiName string = uami.outputs.uamis[0].name
output acrRoleAssignmentId string = acrRbac.outputs.assignmentId
output keyVaultRoleAssignmentId string = keyVaultRbac.outputs.keyVaultRoleAssignmentId
output cosmosDbRoleAssignmentId string = cosmosRbac.outputs.assignmentId
