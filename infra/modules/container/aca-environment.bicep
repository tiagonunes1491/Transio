/*
 * =============================================================================
 * Container Apps Environment Module
 * =============================================================================
 * 
 * This Bicep module creates and configures Azure Container Apps Environment
 * providing a managed serverless environment for running containerized applications.
 * platform for containerized applications with integrated networking, monitoring,
 * and security features optimized for microservices architectures.
 * 
 * ARCHITECTURE OVERVIEW:
 * ┌─────────────────────────────────────────────────────────────────────────┐
 * │                Container Apps Environment Architecture                   │
 * ├─────────────────────────────────────────────────────────────────────────┤
 * │  Container Apps Environment                                             │
 * │  ┌─────────────────────────────────────────────────────────────────────┐│
 * │  │ Control Plane (Azure Managed)                                      ││
 * │  │ ┌─────────────────────┐  ┌─────────────────────────────────────┐   ││
 * │  │ │ Environment Manager │  │ Load Balancer                       │   ││
 * │  │ │ • Container runtime │  │ • Traffic distribution              │   ││
 * │  │ │ • Scaling engine    │  │ • Health checks                     │   ││
 * │  │ │ • Secret management │  │ • SSL termination                   │   ││
 * │  │ └─────────────────────┘  └─────────────────────────────────────┘   ││
 * │  │                                                                     ││
 * │  │ Data Plane (Customer Subnet)                                       ││
 * │  │ ┌─────────────────────┐  ┌─────────────────────────────────────┐   ││
 * │  │ │ Container Instances │  │ Monitoring Integration              │   ││
 * │  │ │ • Application pods  │  │ • Log Analytics                     │   ││
 * │  │ │ • Sidecar services  │  │ • Application logs                  │   ││
 * │  │ │ • Network isolation │  │ • System metrics                    │   ││
 * │  │ └─────────────────────┘  └─────────────────────────────────────┘   ││
 * │  └─────────────────────────────────────────────────────────────────────┘│
 * └─────────────────────────────────────────────────────────────────────────┘
 * 
 * KEY FEATURES:
 * • Managed Serverless Platform: Azure-managed control plane with automatic scaling
 * • VNET Integration: Custom subnet deployment for network isolation
 * • Log Analytics Integration: Centralized logging for all container applications
 * • Health Monitoring: Built-in health checks and observability features
 * • Traffic Management: Automatic load balancing and SSL termination
 * • Secret Management: Secure injection of secrets and configuration
 * • Multi-Container Support: Sidecar patterns and service mesh capabilities
 * 
 * SECURITY CONSIDERATIONS:
 * • Network isolation through dedicated subnet deployment
 * • Secure secret injection without environment variable exposure
 * • Log Analytics integration for security monitoring and audit trails
 * • Container runtime security with Azure security baselines
 * • Traffic encryption with automatic SSL/TLS certificate management
 * • Access control through Azure RBAC and managed identities
 * 
 * DEPLOYMENT SCOPE:
 * This module operates at resource group scope to create a Container Apps
 * Environment that can host multiple containerized applications with shared
 * networking and monitoring infrastructure.
 */
@description('The Azure Container Apps Environment name.')
param acaEnvironmentName string
@description('The location for the Azure Container Apps Environment.')
param acaEnvironmentLocation string = resourceGroup().location
@description('The tags for the Azure Container Apps Environment.')
param acaEnvironmentTags object = {}
@description('The workspace ID for the Azure Container Apps Environment.')
param workspaceId string
@description('The VNET subnet ID the Azure Container Apps Environment.')
param acaEnvironmentSubnetId string


resource acaEnvironment 'Microsoft.App/managedEnvironments@2025-01-01' = {
  name: acaEnvironmentName
  location: acaEnvironmentLocation
  tags: acaEnvironmentTags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: reference(workspaceId, '2022-10-01').customerId
         #disable-next-line use-secure-value-for-secure-inputs
        sharedKey:  listKeys(workspaceId, '2022-10-01').primarySharedKey  // secureString
      }
    }
    vnetConfiguration: {
      infrastructureSubnetId: acaEnvironmentSubnetId
      internal: false
    }
  }
}

output acaEnvironmentId string = acaEnvironment.id
output acaDefaultDomain string = acaEnvironment.properties.defaultDomain
