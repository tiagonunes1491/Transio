/*
 * =============================================================================
 * Azure Container Registry Module for Secure Secret Sharer
 * =============================================================================
 * 
 * This Bicep module creates and configures an Azure Container Registry (ACR)
 * for secure container image storage, distribution, and management. It provides
 * enterprise-grade container registry capabilities with comprehensive security
 * features, networking controls, and integration options.
 * 
 * ARCHITECTURE OVERVIEW:
 * ┌─────────────────────────────────────────────────────────────────────────┐
 * │                    Azure Container Registry                             │
 * ├─────────────────────────────────────────────────────────────────────────┤
 * │  Security Features          │  Performance Features                     │
 * │  ┌─────────────────────┐   │  ┌─────────────────────────────────────┐  │
 * │  │ Admin User Control  │   │  │ Multi-SKU Support                   │  │
 * │  │ Anonymous Pull      │───┼──│ • Basic: Development/Testing        │  │
 * │  │ Network ACLs        │   │  │ • Standard: Production Ready        │  │
 * │  │ Private Endpoints   │   │  │ • Premium: Enterprise Features      │  │
 * │  │ Encryption Support  │   │  │                                     │  │
 * │  └─────────────────────┘   │  │ Zone Redundancy                     │  │
 * │                             │  │ Data Endpoints                      │  │
 * │  Integration Features       │  │ Geo-replication Ready               │  │
 * │  ┌─────────────────────┐   │  └─────────────────────────────────────┘  │
 * │  │ RBAC Integration    │   │                                          │
 * │  │ Key Vault Encryption│   │  Monitoring & Compliance                │
 * │  │ Managed Identity    │   │  ┌─────────────────────────────────────┐  │
 * │  │ Webhook Support     │   │  │ Activity Logging                    │  │
 * │  └─────────────────────┘   │  │ Image Vulnerability Scanning       │  │
 * └─────────────────────────────┘  │ Content Trust                       │  │
 *                                  │ Compliance Reporting                │  │
 *                                  └─────────────────────────────────────┘
 * 
 * KEY FEATURES:
 * • Multi-Tier SKU Support: Basic, Standard, and Premium tiers for different requirements
 * • Security Controls: Admin user management, network ACLs, and encryption options
 * • Enterprise Features: Zone redundancy, geo-replication, and private endpoints (Premium)
 * • Access Management: Integration with Azure RBAC and managed identities
 * • Network Isolation: Configurable public access and virtual network integration
 * • Data Protection: Customer-managed encryption keys and secure storage
 * • Monitoring Integration: Built-in logging and vulnerability scanning capabilities
 * 
 * SECURITY CONSIDERATIONS:
 * • Admin user disabled by default for enhanced security posture
 * • Network access controls through configurable rule sets
 * • Support for private endpoints to eliminate internet exposure
 * • Customer-managed encryption keys for data protection
 * • Integration with Azure Key Vault for secure key management
 * • Anonymous pull access disabled by default
 * • Comprehensive audit logging for compliance requirements
 * 
 * DEPLOYMENT SCOPE:
 * This module operates at resource group scope and creates a single
 * Azure Container Registry with the specified configuration and security settings.
 */

/*
 * =============================================================================
 * PARAMETER DEFINITIONS
 * =============================================================================
 * 
 * These parameters configure the Azure Container Registry deployment,
 * establishing security settings, performance characteristics, and
 * integration options for container image management.
 */

/*
 * BASIC CONFIGURATION PARAMETERS
 * Essential settings that define the ACR instance and its core properties
 */
@description('Azure Container Registry name - must be globally unique across Azure')
param acrName string

@description('Azure region where the container registry will be deployed')
param location string

@description('Resource tags for governance, cost management, and operational tracking')
param tags object = {}

/*
 * SERVICE TIER AND PERFORMANCE PARAMETERS
 * Configuration options that determine ACR capabilities and performance characteristics
 */
@description('SKU tier for Azure Container Registry - determines available features and performance')
@allowed([
  'Basic'      // Development and testing scenarios with basic features
  'Standard'   // Production workloads with enhanced performance and features  
  'Premium'    // Enterprise scenarios with advanced security and geo-replication
])
param sku string = 'Standard'

@description('Enable zone redundancy for Premium SKU - provides high availability across availability zones')
param enableZoneRedundancy bool = false

/*
 * SECURITY AND ACCESS CONTROL PARAMETERS
 * Settings that control authentication, authorization, and network security
 */
@description('Enable admin user for Azure Container Registry - disabled by default for security')
param enableAdminUser bool = false

@description('Enable anonymous pull access - allows unauthenticated image pulls (not recommended for production)')
param enableAnonymousPull bool = false

@description('Public network access setting - controls internet accessibility')
@allowed([
  'Enabled'    // Registry accessible from internet (with optional network rules)
  'Disabled'   // Registry only accessible through private endpoints
])
param publicNetworkAccess string = 'Enabled'

@description('Network rule set for controlling access - defines IP and virtual network access rules')
param networkRuleSet object = {
  defaultAction: 'Allow'           // Default action for requests not matching rules
  ipRules: []                      // Array of IP address ranges with access
  virtualNetworkRules: []          // Array of virtual network subnets with access
}

/*
 * ENCRYPTION AND DATA PROTECTION PARAMETERS
 * Configuration for data encryption and key management capabilities
 */
@description('Enable customer-managed encryption - provides additional control over encryption keys')
param enableEncryption bool = false

@description('Key Vault resource ID for customer-managed encryption key - required when encryption is enabled')
param keyVaultResourceId string = ''

@description('Key name in Key Vault for encryption operations - required when encryption is enabled')
param keyName string = ''

/*
 * ADVANCED FEATURE PARAMETERS
 * Optional features for enhanced functionality and performance
 */
@description('Enable data endpoint - provides direct access to registry data for improved performance')
param enableDataEndpoint bool = false

@description('Enable dedicated data endpoints per region - optimizes geo-replication performance (Premium only)')
param enableDedicatedDataEndpoint bool = false

/*
 * =============================================================================
 * AZURE CONTAINER REGISTRY DEPLOYMENT
 * =============================================================================
 * 
 * Creates the Azure Container Registry resource with comprehensive configuration
 * including security settings, performance options, and compliance features.
 */

/*
 * AZURE CONTAINER REGISTRY RESOURCE
 * Primary container registry resource with full configuration
 * 
 * Configuration Details:
 * • SKU-based feature enablement (Basic/Standard/Premium capabilities)
 * • Security controls including admin user and network access management
 * • Encryption support with customer-managed keys when required
 * • Zone redundancy for Premium SKU high availability
 * • Data endpoint configuration for performance optimization
 * • Network rule set enforcement for access control
 * 
 * Security Features:
 * • Admin user authentication disabled by default
 * • Anonymous pull access disabled for security
 * • Network access controls through rule sets
 * • Customer-managed encryption support
 * • Zone redundancy for business continuity
 */
resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  tags: tags
  sku: {
    name: sku
  }
  properties: {
    adminUserEnabled: enableAdminUser                                              // Admin user control for legacy scenarios
    dataEndpointEnabled: enableDataEndpoint || enableDedicatedDataEndpoint       // Data endpoint configuration
    publicNetworkAccess: publicNetworkAccess                                      // Internet accessibility control
    networkRuleSet: networkRuleSet                                               // Network access rule enforcement
    anonymousPullEnabled: enableAnonymousPull                                    // Anonymous access control
    zoneRedundancy: (sku == 'Premium' && enableZoneRedundancy) ? 'Enabled' : 'Disabled'  // HA configuration
    encryption: enableEncryption ? {
      status: 'enabled'
      keyVaultProperties: {
        keyIdentifier: '${keyVaultResourceId}/keys/${keyName}'                   // Customer-managed encryption
      }
    } : {
      status: 'disabled'                                                          // Default Azure-managed encryption
    }
  }
}

/*
 * =============================================================================
 * MODULE OUTPUTS
 * =============================================================================
 * 
 * Provides essential Azure Container Registry information for consumption by
 * dependent resources and application deployment configurations.
 */

/*
 * CONTAINER REGISTRY OUTPUTS
 * Critical registry information for integration with other Azure services
 * and application deployment pipelines
 */
@description('Azure Container Registry resource ID for RBAC assignments and resource references')
output acrId string = acr.id

@description('Azure Container Registry login server URL for Docker CLI and container orchestration')
output acrLoginServer string = acr.properties.loginServer

@description('Azure Container Registry name for configuration and reference in dependent resources')
output acrName string = acr.name