/*
 * =============================================================================
 * Log Analytics Workspace Module
 * =============================================================================
 * 
 * This Bicep module creates and configures Azure Log Analytics Workspace
 * for centralized monitoring, logging, and observability.
 * Sharer application. It provides the foundation for security monitoring,
 * performance analysis, and operational insights across all platform components.
 * 
 * ARCHITECTURE OVERVIEW:
 * ┌─────────────────────────────────────────────────────────────────────────┐
 * │                 Log Analytics Workspace Architecture                    │
 * ├─────────────────────────────────────────────────────────────────────────┤
 * │  Data Collection and Analysis                                           │
 * │  ┌─────────────────────────────────────────────────────────────────────┐│
 * │  │ Data Sources                                                        ││
 * │  │ ┌─────────────────────┐  ┌─────────────────────────────────────┐   ││
 * │  │ │ Application Logs    │  │ Infrastructure Metrics              │   ││
 * │  │ │ • Container Apps    │  │ • Azure Monitor                     │   ││
 * │  │ │ • Static Web Apps   │  │ • Key Vault events                  │   ││
 * │  │ │ • Custom metrics    │  │ • Network security logs             │   ││
 * │  │ └─────────────────────┘  └─────────────────────────────────────┘   ││
 * │  │                                                                     ││
 * │  │ Analytics and Insights                                              ││
 * │  │ ┌─────────────────────┐  ┌─────────────────────────────────────┐   ││
 * │  │ │ KQL Queries         │  │ Alerting and Monitoring             │   ││
 * │  │ │ • Security analysis │  │ • Real-time alerts                  │   ││
 * │  │ │ • Performance tuning│  │ • Threshold monitoring              │   ││
 * │  │ │ • Cost optimization │  │ • Anomaly detection                 │   ││
 * │  │ └─────────────────────┘  └─────────────────────────────────────┘   ││
 * │  └─────────────────────────────────────────────────────────────────────┘│
 * └─────────────────────────────────────────────────────────────────────────┘
 * 
 * KEY FEATURES:
 * • Centralized Logging: Single destination for all application and infrastructure logs
 * • Pay-per-GB Pricing: Cost-effective PerGB2018 pricing model for flexible scaling
 * • Retention Management: Configurable data retention for compliance requirements
 * • KQL Analytics: Powerful Kusto Query Language for deep data analysis
 * • Integration Ready: Seamless integration with Container Apps and Azure Monitor
 * • Security Monitoring: Foundation for Azure Sentinel and security analytics
 * • Performance Insights: Application performance monitoring and optimization
 * 
 * SECURITY CONSIDERATIONS:
 * • Centralized audit trail for all platform activities and security events
 * • Access control through Azure RBAC for log data security
 * • Data retention policies for compliance with regulatory requirements
 * • Integration with Azure Security Center for threat detection
 * • Network security log collection for intrusion detection
 * • Application security monitoring through custom log collection
 * 
 * DEPLOYMENT SCOPE:
 * This module operates at resource group scope to create a Log Analytics
 * workspace that serves as the central monitoring hub for all Secure Secret
 * Sharer infrastructure and application components.
 */
@description('Name of the workspace')
param workspaceName string
@description('Location for the workspace')
param location string = resourceGroup().location
@description('Tags for the workspace')
param tags object = {}

resource workspace 'Microsoft.OperationalInsights/workspaces@2025-02-01' = {
  name: workspaceName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30 // Default retention period}
  }
}

output workspaceId string = workspace.id
output workspaceName string = workspace.name
output workspaceCustomerId string = workspace.properties.customerId
@secure()
output workspaceSharedKey string = listKeys(workspace.id, '2022-10-01').primarySharedKey
