// infra/31-swa-identity/main.bicep
// SWA Identity deployment: Creates UAMI and configures RBAC for services

targetScope = 'resourceGroup'

@description('Deployment location')
param resourceLocation string = 'spaincentral'

@description('Project code')
param projectCode string = 'ss'

@description('Service code for SWA/ACA platform')
param serviceCode string = 'swa'

@description('Environment name')
@allowed(['dev', 'prod'])
param environmentName string = 'dev'

// Tagging configuration
@description('Cost center for billing')
param costCenter string = '1000'

@description('Created by information')
param createdBy string = 'bicep-deployment'

@description('Owner')
param owner string = 'tiago-nunes'

@description('Owner email')
param ownerEmail string = 'tiago.nunes@example.com'

// ========== SHARED INFRASTRUCTURE REFERENCES ==========
@description('Shared Resource Group Name (where ACR and CosmosDB are located)')
param sharedResourceGroupName string

@description('Key Vault Resource Group Name (where Key Vault is located)')
param keyVaultResourceGroupName string

@description('Existing ACR name from shared infrastructure')
param acrName string

@description('Existing Cosmos DB account name from shared infrastructure')
param cosmosDbAccountName string

@description('Existing Key Vault name')
param keyVaultName string

@description('Cosmos DB database name to scope the RBAC assignment to')
param cosmosDatabaseName string = 'secrets-db'

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
  params: {
    registryId: sssplatacr.id
    principalId: uami.outputs.uamis[0].principalId
    roleDefinitionId: '7f951dda-4ed3-4680-a7ca-43fe172d538d' // AcrPull role
  }
}

// Deploy Key Vault RBAC at the Key Vault scope
module keyVaultRbac '../40-modules/core/rbacKv.bicep' = {
  name: 'keyVaultRbac'
  params: {
    vaultId: akv.id
    principalId: uami.outputs.uamis[0].principalId
    roleDefinitionId: '4633458b-17de-408a-b874-0445c86b69e6' // Key Vault Secrets User role
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
output keyVaultRoleAssignmentId string = keyVaultRbac.outputs.assignmentId
output cosmosDbRoleAssignmentId string = cosmosRbac.outputs.assignmentId
