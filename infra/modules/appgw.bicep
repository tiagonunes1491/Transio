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


@description('Hostname to use for health probes')
param hostName string = 'secretsharer.example.com'

@description('Backend pool configurations')
param backendPools array = [
  {
    name: 'pool-frontend'
    ipAddresses: []
    port: 8080
    protocol: 'Http'
    path: '/'
    healthProbePath: '/'
    healthProbeInterval: 10
    healthProbeTimeout: 5
  }
  {
    name: 'pool-backend'
    ipAddresses: []
    port: 5000
    protocol: 'Http'
    path: '/'
    healthProbePath: '/health'
    healthProbeInterval: 15
    healthProbeTimeout: 5
  }
]

@description('Path routing rules')
param pathRules array = [
  {
    name: 'rule-api'
    paths: ['/api*']
    backendPoolName: 'pool-backend'
  }
]

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
    backendAddressPools: [for pool in backendPools: {
      name: pool.name
      properties: {
        backendAddresses: pool.ipAddresses
      }
    }]
    backendHttpSettingsCollection: [for pool in backendPools: {
      name: 'bp-${pool.name}-${pool.port}'
      properties: {
        port: pool.port
        protocol: pool.protocol
        cookieBasedAffinity: 'Disabled'
        requestTimeout: 30
        pickHostNameFromBackendAddress: false
        path: pool.path
        probe: {
          id: resourceId('Microsoft.Network/applicationGateways/probes', appGwName, 'pb-${pool.name}')
        }
      }
    }]
    httpListeners: [
      {
        name: 'fl-http'
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
    urlPathMaps: [
      {
        name: 'url-path-map'
        properties: {
          defaultBackendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appGwName, 'pool-frontend')
          }
          defaultBackendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appGwName, 'bp-pool-frontend-8080')
          }
          pathRules: [for rule in pathRules: {
            name: rule.name
            properties: {
              paths: rule.paths
              backendAddressPool: {
                id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appGwName, rule.backendPoolName)
              }
              backendHttpSettings: {
              id: resourceId(
                'Microsoft.Network/applicationGateways/backendHttpSettingsCollection', 
                appGwName, 
                'bp-${rule.backendPoolName}-${first(filter(backendPools, p => p.name == rule.backendPoolName)).port}'
              )
              }
            }
          }]
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'rr-http'
        properties: {
          ruleType: 'PathBasedRouting'
          priority: 100
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appGwName, 'fl-http')
          }
          urlPathMap: {
            id: resourceId('Microsoft.Network/applicationGateways/urlPathMaps', appGwName, 'url-path-map')
          }
        }
      }
    ]
    probes: [for pool in backendPools: {
      name: 'pb-${pool.name}'
      properties: {
        protocol: pool.protocol
        host: hostName
        path: pool.healthProbePath
        interval: pool.healthProbeInterval
        timeout: pool.healthProbeTimeout
        unhealthyThreshold: 3
        pickHostNameFromBackendHttpSettings: false
        minServers: 0
        match: {
          statusCodes: [
            '200-399'
          ]
        }
      }
    }]
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
