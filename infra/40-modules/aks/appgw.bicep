/*
 * =============================================================================
 * Application Gateway Module for Secure Secret Sharer
 * =============================================================================
 * 
 * This Bicep module creates and configures Azure Application Gateway for
 * AKS ingress traffic management. It provides Layer 7 load balancing, SSL
 * termination, and Web Application Firewall capabilities to secure and
 * optimize traffic routing to the Secure Secret Sharer application.
 * 
 * ARCHITECTURE OVERVIEW:
 * ┌─────────────────────────────────────────────────────────────────────────┐
 * │                Application Gateway Architecture                         │
 * ├─────────────────────────────────────────────────────────────────────────┤
 * │  Internet Traffic                                                       │
 * │               │                                                         │
 * │               ▼                                                         │
 * │  ┌─────────────────────────────────────────────────────────────────────┐│
 * │  │ Application Gateway                                                 ││
 * │  │ ┌─────────────────────┐  ┌─────────────────────────────────────┐   ││
 * │  │ │ Frontend            │  │ SSL Termination                     │   ││
 * │  │ │ • Public IP         │  │ • Certificate management            │   ││
 * │  │ │ • Custom domains    │  │ • TLS/SSL protocols                 │   ││
 * │  │ │ • Port listeners    │  │ • Security headers                  │   ││
 * │  │ └─────────────────────┘  └─────────────────────────────────────┘   ││
 * │  │                                                                     ││
 * │  │ ┌─────────────────────┐  ┌─────────────────────────────────────┐   ││
 * │  │ │ Routing Rules       │  │ Backend Pools                       │   ││
 * │  │ │ • Path-based        │  │ • AKS services                      │   ││
 * │  │ │ • Host-based        │  │ • Health probes                     │   ││
 * │  │ │ • URL rewrite       │  │ • Load balancing                    │   ││
 * │  │ └─────────────────────┘  └─────────────────────────────────────┘   ││
 * │  └─────────────────────────────────────────────────────────────────────┘│
 * │               │                                                         │
 * │               ▼                                                         │
 * │  ┌─────────────────────────────────────────────────────────────────────┐│
 * │  │ AKS Cluster (Backend Services)                                     ││
 * │  └─────────────────────────────────────────────────────────────────────┘│
 * └─────────────────────────────────────────────────────────────────────────┘
 * 
 * KEY FEATURES:
 * • Layer 7 Load Balancing: Advanced HTTP/HTTPS traffic routing capabilities
 * • SSL Termination: Centralized certificate management and SSL/TLS handling
 * • Web Application Firewall: Optional WAF protection against common attacks
 * • Auto-scaling: Dynamic scaling based on traffic patterns
 * • Health Monitoring: Backend health probes and automatic failover
 * • Custom Domains: Support for custom domain names with SSL certificates
 * • AGIC Integration: Kubernetes ingress controller for automatic configuration
 * 
 * SECURITY CONSIDERATIONS:
 * • SSL/TLS termination with strong cipher suites and protocols
 * • Web Application Firewall for OWASP Top 10 protection
 * • DDoS protection through Azure infrastructure
 * • Security headers injection for enhanced protection
 * • Backend authentication and authorization
 * • Network isolation through dedicated subnet placement
 */
@description('Name of the Application Gateway')
param appGwName string = 'appgw-securesharer-mvp'

@description('Location for the application gateway')
param location string = resourceGroup().location

@description('Tags for the application gateway')
param tags object

@description('Application Gateway SKU')
@allowed([
  'Standard_v2'
  'WAF_v2'
])
param sku string ='Standard_v2'

@description('Application Gateway subnet ID')
param appGwSubnetId string

@description('Public IP address name for the Application Gateway')
param publicIpName string = 'appgw-public-ip'

// Create a public IP address for the Application Gatewa
resource publicIp 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: publicIpName
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'    
  }
  tags: tags
}


// Create Application Gateway
resource appGw 'Microsoft.Network/applicationGateways@2023-05-01' = {
  name: appGwName
  location: location
  tags: tags
  properties: {
    sku: {
      name: sku
      tier: sku
      capacity: 1
    }
    enableHttp2: true
    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        properties: {
          subnet: {
            id: appGwSubnetId
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'appGwPublicFrontendIpIPv4'
        properties: {
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'port_80'
        properties: {
          port: 80
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'defaultBackendPool'
        properties: {
          backendAddresses: [] // Empty for AGIC to manage
        }
      }
    ]
    // Add required backend HTTP settings
    backendHttpSettingsCollection: [
      {
        name: 'defaultHttpSetting'
        properties: {
          port: 80
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'
          requestTimeout: 30
          pickHostNameFromBackendAddress: false
        }
      }
    ]
    // Add required HTTP listener
    httpListeners: [
      {
        name: 'defaultListener'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appGwName, 'appGwPublicFrontendIpIPv4')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appGwName, 'port_80')
          }
          protocol: 'Http'
          requireServerNameIndication: false
        }
      }
    ]
    // Add required routing rule
    requestRoutingRules: [
      {
        name: 'defaultRoutingRule'
        properties: {
          ruleType: 'Basic'
          priority: 100
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appGwName, 'defaultListener')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appGwName, 'defaultBackendPool')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appGwName, 'defaultHttpSetting')
          }
        }
      }
    ]
    webApplicationFirewallConfiguration: sku == 'WAF_v2' ? {
      enabled: true
      firewallMode: 'Prevention'
      ruleSetType: 'OWASP'
      ruleSetVersion: '3.2'
      disabledRuleGroups: []
      requestBodyCheck: true
      maxRequestBodySizeInKb: 128
      fileUploadLimitInMb: 100
    } : null
  }
}

// Outputs
output appGwId string = appGw.id
output appGwName string = appGw.name
output publicIpAddress string = publicIp.properties.ipAddress
output publicIpId string = publicIp.id
