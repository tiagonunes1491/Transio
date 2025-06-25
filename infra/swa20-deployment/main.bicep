/*
 * =============================================================================
 * SWA Application Deployment Infrastructure for Secure Secret Sharer
 * =============================================================================
 * 
 * This Bicep template creates the actual application deployment infrastructure
 * for the Secure Secret Sharer project using Static Web Apps and Container Apps.
 * It deploys the frontend and backend components onto the previously established
 * platform infrastructure with secure connectivity and proper configuration.
 * 
 * ARCHITECTURE OVERVIEW:
 * ┌─────────────────────────────────────────────────────────────────────────┐
 * │                    SWA Application Deployment                           │
 * ├─────────────────────────────────────────────────────────────────────────┤
 * │  Application Resource Group                                             │
 * │  ┌─────────────────────────────────────────────────────────────────────┐│
 * │  │ Frontend Components                                                 ││
 * │  │ ┌─────────────────────┐                                           ││
 * │  │ │ Static Web App      │ ← GitHub Integration                      ││
 * │  │ │ • React Frontend    │ ← Custom Domain Support                   ││
 * │  │ │ • Global CDN        │ ← SSL/TLS Termination                     ││
 * │  │ │ • Authentication    │                                           ││
 * │  │ └─────────────────────┘                                           ││
 * │  │                                                                    ││
 * │  │ Backend Components                                                 ││
 * │  │ ┌─────────────────────┐                                           ││
 * │  │ │ Container App       │ ← Managed Identity Authentication         ││
 * │  │ │ • API Backend       │ ← Environment Variables from Key Vault    ││
 * │  │ │ • Auto Scaling      │ ← Private Network Connectivity            ││
 * │  │ │ • Health Probes     │ ← Container Registry Integration          ││
 * │  │ └─────────────────────┘                                           ││
 * │  └─────────────────────────────────────────────────────────────────────┘│
 * │                                                                         │
 * │  Integration Points:                                                    │
 * │  • Container Apps Environment (existing platform infrastructure)       │
 * │  • User-Assigned Managed Identity (from identity deployment)           │
 * │  • Key Vault secrets injection for secure configuration                │
 * │  • Container Registry for backend image deployment                     │
 * └─────────────────────────────────────────────────────────────────────────┘
 * 
 * KEY FEATURES:
 * • Static Web App Frontend: React application with global CDN and auto-scaling
 * • Container App Backend: Scalable API service with health monitoring
 * • Managed Identity Integration: Secure authentication without credentials
 * • Key Vault Secret Injection: Secure configuration management
 * • GitHub Integration: Automated deployment workflows
 * • Custom Domain Support: Production-ready hosting with SSL/TLS
 * • Auto-scaling: Dynamic resource allocation based on demand
 * • Health Monitoring: Built-in application health checks and observability
 * 
 * SECURITY CONSIDERATIONS:
 * • Managed identity authentication eliminates credential storage
 * • Key Vault integration for secure secrets management
 * • Private network connectivity for backend services
 * • Authentication and authorization through Azure AD integration
 * • Container image security through Azure Container Registry
 * • SSL/TLS encryption for all external communications
 * • Network isolation through Container Apps Environment networking
 * 
 * DEPLOYMENT SCOPE:
 * This template operates at resource group scope to deploy application
 * components that utilize existing platform infrastructure including
 * Container Apps Environment, networking, and identity management.
 */
targetScope = 'resourceGroup'

/*
 * =============================================================================
 * PARAMETERS
 * =============================================================================
 */

// ========== CORE DEPLOYMENT PARAMETERS ==========

@description('Azure region for application deployment matching platform infrastructure')
param resourceLocation string = 'spaincentral'

@description('Short project identifier used in resource naming conventions')
param projectCode string = 'ss'

@description('Service identifier for this SWA application deployment')
param serviceCode string = 'swa'

@description('Target environment affecting application configuration and scaling')
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

// ========== EXISTING INFRASTRUCTURE REFERENCES ==========

@description('Name of resource group containing the Container Apps Environment')
param acaEnvironmentResourceGroupName string

@description('Name of existing Container Apps Environment for backend deployment')
param acaEnvironmentName string

@description('Name of resource group containing the User-Assigned Managed Identity')
param uamiResourceGroupName string

@description('Name of existing User-Assigned Managed Identity for secure authentication')
param uamiName string


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


// ========== APPLICATION CONFIGURATION PARAMETERS ==========

@description('Full container image reference including registry and tag for backend deployment')
param containerImage string

@description('Array of Key Vault secret references for secure application configuration')
param keyVaultSecrets array = []

@description('Environment variables for the Container App')
param environmentVariables array = []

@description('Secret environment variables for the Container App')
param secretEnvironmentVariables array = []

// Reference existing infrastructure
resource acaEnv 'Microsoft.App/managedEnvironments@2025-01-01' existing = {
  name: acaEnvironmentName
  scope: resourceGroup(subscription().subscriptionId, acaEnvironmentResourceGroupName)
}


// ========== NAMING AND TAGGING MODULES ==========

// Generate standardized tags using the tagging module
module standardTagsModule '../40-modules/core/tagging.bicep' = {
  scope: subscription()
  name: 'standard-tags-swa-app'
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

module containerAppNamingModule '../40-modules/core/naming.bicep' = {
  scope: subscription()
  name: 'container-app-naming'
  params: {
    projectCode: projectCode
    environment: environmentName
    serviceCode: serviceCode
    resourceType: 'ca'
  }
}

module swaNamingModule '../40-modules/core/naming.bicep' = {
  scope: subscription()
  name: 'swa-naming'
  params: {
    projectCode: projectCode
    environment: environmentName
    serviceCode: serviceCode
    resourceType: 'swa'
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
    keyVaultId: akv.id
    id: uami.outputs.uamis[0].principalId
    roleId: '4633458b-17de-408a-b874-0445c86b69e6' // Key Vault Secrets User role
  }
}


// Deploy Cosmos DB RBAC in the shared resource group
module cosmosRbac '../40-modules/core/rbacCosmos.bicep' = {
  name: 'cosmosRbac'
  params: {
    accountName: sssplatcosmos.name
    principalId: uami.outputs.uamis[0].principalId
    roleDefinitionId: '00000000-0000-0000-0000-000000000002' // Cosmos DB Built-in Data Contributor role
    databaseName: cosmosDatabaseName
  }
}



// ========== CONTAINER APP (using UAMI) ==========
// Dynamically add AZURE_CLIENT_ID to environment variables
var containerAppEnvironmentVariables = union(environmentVariables, [
  {
    name: 'AZURE_CLIENT_ID'
    value: uami.outputs.uamis[0].clientId
  }
])

module containerApp '../40-modules/core/container-app.bicep' = {
  name: 'containerApp'
  params: {
    containerAppName: containerAppNamingModule.outputs.resourceName
    environmentId: acaEnv.id
    image: containerImage
    location: resourceLocation
    tags: standardTagsModule.outputs.tags
    identity: {
      type: 'UserAssigned'
      userAssignedIdentities: {
        '${uami.outputs.uamis[0].clientId}': {}
      }
    }
    secrets: [for secret in keyVaultSecrets: {      name: secret.name
      keyVaultUrl: secret.keyVaultUrl
      identity: uami.outputs.uamis[0].clientId
    }]
    registries: [
      {
        server: split(containerImage, '/')[0] // Extract ACR server from image
        identity: uami.outputs.uamis[0].clientId
      }
    ]
    environmentVariables: containerAppEnvironmentVariables
    secretEnvironmentVariables: secretEnvironmentVariables
    targetPort: 5000 // Flask app runs on port 5000
    externalIngress: true // Enable external access
    enableIngress: true
    ingressTransport: 'auto'
  }
}

// ========== STATIC WEB APP ==========
module staticWebApp '../40-modules/core/static-web-app.bicep' = {
  name: 'staticWebApp'
  params: {
    swaName: swaNamingModule.outputs.resourceName
    location: 'westeurope' // Static Web Apps aren't supported in Spain Central (yet)
    backendResourceId: containerApp.outputs.containerAppId // Link to Container App for API routing
    tags: standardTagsModule.outputs.tags
    sku: 'Standard' // Use Standard SKU for production features
    allowConfigFileUpdates: true
    provider: 'None' // Manual deployment, not from repository
    stagingEnvironmentPolicy: 'Enabled'
    enterpriseGradeCdnStatus: 'Disabled'
    linkedBackendName: 'containerapp'
  }
}

// ========== OUTPUTS ==========
output containerAppId string = containerApp.outputs.containerAppId
output containerAppName string = containerAppNamingModule.outputs.resourceName
output staticWebAppId string = staticWebApp.outputs.staticWebAppId
output staticWebAppName string = swaNamingModule.outputs.resourceName
output staticWebAppHostname string = staticWebApp.outputs.staticWebAppHostname
