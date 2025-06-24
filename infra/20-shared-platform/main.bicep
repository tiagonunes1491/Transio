/*
 * =============================================================================
 * Shared Platform Infrastructure for Secure Secret Sharer
 * =============================================================================
 * 
 * This Bicep template deploys the shared platform infrastructure components
 * for the Secure Secret Sharer project. It establishes the core services that
 * support both Kubernetes (AKS) and Platform-as-a-Service (SWA) workloads
 * with secure, scalable, and well-governed container and data management.
 * 
 * ARCHITECTURE OVERVIEW:
 * ┌─────────────────────────────────────────────────────────────────────────┐
 * │                       Shared Platform Services                         │
 * ├─────────────────────────────────────────────────────────────────────────┤
 * │  Container Management       │  Data Management                          │
 * │  ┌─────────────────────┐   │  ┌─────────────────────────────────────┐  │
 * │  │ Azure Container     │   │  │ Azure Cosmos DB                     │  │
 * │  │ Registry (ACR)      │───┼──│ Multi-Database Support              │  │
 * │  │                     │   │  │                                     │  │
 * │  │ Premium SKU         │   │  │ Environment Separation              │  │
 * │  │ Image Storage       │   │  │ • swa-dev/swa-prod                  │  │
 * │  │ Security Scanning   │   │  │ • aks-dev/aks-prod                  │  │
 * │  │ Geo-replication     │   │  │                                     │  │
 * │  │                     │   │  │ Auto-scaling Support                │  │
 * │  └─────────────────────┘   │  └─────────────────────────────────────┘  │
 * └─────────────────────────────────────────────────────────────────────────┘
 * 
 * KEY FEATURES:
 * • Container Registry: Premium ACR for secure image storage and distribution
 * • Multi-Environment Data: Separate Cosmos DB databases for dev/prod isolation
 * • Security Integration: Built-in vulnerability scanning and access controls
 * • Performance Optimization: Auto-scaling configurations for all data containers
 * • Cross-Platform Support: Shared services for both AKS and SWA workloads
 * • Naming Standards: Consistent, predictable resource naming across environments
 * • Comprehensive Tagging: Full metadata strategy for governance and cost tracking
 * 
 * SECURITY CONSIDERATIONS:
 * • ACR admin user disabled by default for enhanced security
 * • Cosmos DB configured with appropriate partition strategies
 * • TTL policies configured for automatic data lifecycle management
 * • Resource-level access controls through Azure RBAC
 * • Comprehensive audit trails through tagging and deployment tracking
 * 
 * DEPLOYMENT SCOPE:
 * This template operates at resource group scope and deploys platform
 * services that are shared across multiple workload types and environments.
 */

/*
 * =============================================================================
 * PARAMETER DEFINITIONS
 * =============================================================================
 * 
 * These parameters configure the shared platform deployment, establishing
 * service configurations, data structures, and security settings that
 * will be used by dependent application workloads.
 */

/*
 * INFRASTRUCTURE CONFIGURATION PARAMETERS
 * Core settings that define the deployment location and service specifications
 */
@description('Azure region where shared platform resources will be deployed')
param resourceLocation string = 'spaincentral'

@description('Environment for deployment - determines database and resource configurations')
@allowed(['dev', 'prod', 'shared'])
param environment string = 'shared'

/*
 * ORGANIZATIONAL NAMING PARAMETERS
 * These parameters establish the naming hierarchy for all resources:
 * Pattern: {projectCode}-{environment}-{serviceCode}-{resourceType}
 */
@description('Project code - root identifier for the Secure Secret Sharer project')
param projectCode string = 'ss'

@description('Service code for shared platform services - identifies shared infrastructure components')
param serviceCode string = 'plat'

/*
 * GOVERNANCE AND COMPLIANCE PARAMETERS
 * Essential metadata for resource governance, cost management, and audit compliance
 */
@description('Cost center for billing allocation and financial tracking')
param costCenter string = '1000'

@description('Deployment method identifier - tracks infrastructure provisioning source')
param createdBy string = 'bicep-deployment'

@description('Primary resource owner - accountable person for these infrastructure components')
param owner string = 'tiago-nunes'

@description('Owner contact email - primary point of contact for operational issues')
param ownerEmail string = 'tiago.nunes@example.com'

@description('Resource creation timestamp - automatically populated with current UTC date')
param createdDate string = utcNow('yyyy-MM-dd')

/*
 * AZURE CONTAINER REGISTRY CONFIGURATION
 * Settings for the shared container registry that serves all workload types
 */
@description('SKU tier for Azure Container Registry - Premium recommended for production workloads')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param acrSku string = 'Premium'

@description('Enable admin user for Azure Container Registry - disabled by default for security')
param acrEnableAdminUser bool = false

/*
 * COSMOS DB CONFIGURATION
 * Data platform configuration supporting multiple environments and workload types
 * Each database is configured with appropriate containers and auto-scaling settings
 * 
 * Database Structure:
 * • swa-dev/swa-prod: Static Web App environments
 * • aks-dev/aks-prod: Kubernetes environments
 * • Each contains 'secret' container with optimized partition strategy
 * • TTL configured for automatic data lifecycle management
 * • Auto-scaling enabled for performance optimization
 */

@description('Cosmos DB database and container configuration for multi-environment support')
param cosmosDbConfig array = [
  {
    name: 'swa-dev'                                    // Static Web App development environment
    containers: [
      {
        name: 'secret'                                 // Secret storage container
        partitionKey: { paths: ['/link_id'], kind: 'Hash' }  // Optimized partitioning strategy
        defaultTtl: 86400                             // 24-hour TTL for automatic cleanup
        autoscaleSettings: { maxThroughput: 1000 }    // Auto-scaling configuration
      }
    ]
  }
  {
    name: 'swa-prod'                                   // Static Web App production environment
    containers: [
      {
        name: 'secret'                                 // Secret storage container
        partitionKey: { paths: ['/link_id'], kind: 'Hash' }  // Optimized partitioning strategy
        defaultTtl: 86400                             // 24-hour TTL for automatic cleanup
        autoscaleSettings: { maxThroughput: 1000 }    // Auto-scaling configuration
      }
    ]
  }
  {
    name: 'aks-dev'                                    // Kubernetes development environment
    containers: [
      {
        name: 'secret'                                 // Secret storage container
        partitionKey: { paths: ['/link_id'], kind: 'Hash' }  // Optimized partitioning strategy
        defaultTtl: 86400                             // 24-hour TTL for automatic cleanup
        autoscaleSettings: { maxThroughput: 1000 }    // Auto-scaling configuration
      }
    ]
  }
  {
    name: 'aks-prod'                                   // Kubernetes production environment
    containers: [
      {
        name: 'secret'                                 // Secret storage container
        partitionKey: { paths: ['/link_id'], kind: 'Hash' }  // Optimized partitioning strategy
        defaultTtl: 86400                             // 24-hour TTL for automatic cleanup
        autoscaleSettings: { maxThroughput: 1000 }    // Auto-scaling configuration
      }
    ]
  }
]

@description('Enable Cosmos DB free tier - not supported on internal/enterprise subscriptions')
param cosmosEnableFreeTier bool = false

/*
 * =============================================================================
 * NAMING CONVENTION AND TAGGING STRATEGY
 * =============================================================================
 * 
 * Establishes consistent naming patterns and comprehensive tagging for all
 * shared platform resources, ensuring governance and operational clarity.
 */

/*
 * CENTRALIZED TAGGING MODULE
 * Uses the organization's standard tagging module to ensure consistency
 * across all platform components and compliance with tagging policies
 */
module standardTagsModule '../40-modules/core/tagging.bicep' = {
  name: 'standard-tags-platform'
  scope: subscription()
  params: {
    environment: environment
    project: projectCode
    service: serviceCode
    costCenter: costCenter
    createdBy: createdBy
    owner: owner
    ownerEmail: ownerEmail
    createdDate: createdDate
  }
}

/*
 * CENTRALIZED NAMING MODULES FOR PLATFORM RESOURCES
 * Uses the organization's standard naming module to ensure consistency
 * across all platform components and compliance with naming policies
 */

/*
 * AZURE CONTAINER REGISTRY NAMING
 * Generates standardized name for the shared container registry
 * Follows pattern: {projectCode}{environment}{serviceCode}{resourceType}
 * Example: sssharedplatacr (sanitized for ACR naming requirements)
 */
module acrNamingModule '../40-modules/core/naming.bicep' = {
  name: 'acr-naming'
  scope: subscription()
  params: {
    projectCode: projectCode
    environment: environment
    serviceCode: serviceCode
    resourceType: 'acr'
  }
}

/*
 * COSMOS DB NAMING
 * Generates standardized name for the shared Cosmos DB account
 * Follows pattern: {projectCode}{environment}{serviceCode}{resourceType}
 * Example: sssharedplatcosmos (sanitized for Cosmos DB naming requirements)
 */
module cosmosNamingModule '../40-modules/core/naming.bicep' = {
  name: 'cosmos-naming'
  scope: subscription()
  params: {
    projectCode: projectCode
    environment: environment
    serviceCode: serviceCode
    resourceType: 'cosmos'
  }
}

/*
 * =============================================================================
 * SHARED PLATFORM SERVICES DEPLOYMENT
 * =============================================================================
 * 
 * Deploys the core platform services that support multiple workload types
 * and environments with secure, scalable, and well-governed configurations.
 */

/*
 * AZURE CONTAINER REGISTRY DEPLOYMENT
 * Premium SKU container registry for secure image storage and distribution
 * 
 * Features:
 * • Premium SKU for geo-replication and advanced security features
 * • Admin user disabled by default for enhanced security
 * • Integration with Azure RBAC for access control
 * • Automatic vulnerability scanning capabilities
 * • Support for OCI artifacts and Helm charts
 * 
 * Security considerations:
 * • Access controlled through managed identities and RBAC
 * • Image scanning enabled for vulnerability detection
 * • Network access can be restricted through private endpoints
 */

module acr '../40-modules/core/acr.bicep' = {
  name: 'acr'
  params: {
    tags: standardTagsModule.outputs.tags
    acrName: acrNamingModule.outputs.resourceName
    location: resourceLocation
    sku: acrSku
    enableAdminUser: acrEnableAdminUser
  }
}

/*
 * COSMOS DB DEPLOYMENT
 * Multi-database NoSQL data platform supporting all workload environments
 * 
 * Features:
 * • Separate databases for environment isolation (dev/prod)
 * • Support for both AKS and SWA workloads
 * • Auto-scaling enabled for performance optimization
 * • TTL configured for automatic data lifecycle management
 * • Optimized partition strategies for high performance
 * 
 * Database Configuration:
 * • swa-dev/swa-prod: Static Web App data isolation
 * • aks-dev/aks-prod: Kubernetes workload data isolation
 * • Each database contains 'secret' container with link_id partitioning
 * • 24-hour TTL for automatic secret expiration and cleanup
 * • Auto-scaling up to 1000 RU/s for performance under load
 * 
 * Security considerations:
 * • Network access controlled through Azure networking
 * • Data encryption at rest and in transit
 * • Access controlled through connection strings and managed identities
 * • Regular backup configured for data protection
 */
module cosmosDb '../40-modules/core/cosmos-db.bicep' = {
  name: 'deploy-cosmos-db'
  params: {
    cosmosDbAccountName: cosmosNamingModule.outputs.resourceName
    location: resourceLocation
    databases: cosmosDbConfig
    tags: standardTagsModule.outputs.tags
    enableFreeTier: cosmosEnableFreeTier    // Disabled for enterprise subscriptions
  }
}

/*
 * =============================================================================
 * TEMPLATE OUTPUTS
 * =============================================================================
 * 
 * Provides essential shared platform information for consumption by
 * dependent application deployment templates and workload configurations.
 */

/*
 * CONTAINER REGISTRY OUTPUTS
 * Critical container registry information for image push/pull operations
 * These outputs enable dependent templates to reference the shared ACR securely
 */
@description('Azure Container Registry name for image storage and distribution')
output acrName string = acr.outputs.acrName

@description('Azure Container Registry login server URL for Docker operations')
output acrLoginServer string = acr.outputs.acrLoginServer

/*
 * COSMOS DB OUTPUTS
 * Essential database connectivity information for application workloads
 * These outputs enable dependent templates to configure data access securely
 */
@description('Cosmos DB account endpoint URL for database connectivity')
output cosmosDbEndpoint string = cosmosDb.outputs.cosmosDbEndpoint

@description('Cosmos DB account name for configuration and access control')
output cosmosDbAccountName string = cosmosDb.outputs.cosmosDbAccountName

@description('Array of created Cosmos DB databases with configuration details')
output cosmosDbDatabases array = cosmosDb.outputs.databases
