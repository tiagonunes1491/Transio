@description('Name of the Application Gateway')
param appGwName string

@description('Location for the application gateway')
param location string = resourceGroup().location

@description('Tags for the application gateway')
param tags object = {}

@description('Application Gateway SKU')
@allowed([
  'Standard_v2'
  'WAF_v2'
])
param sku string = 'Standard_v2'

@description('Application Gateway capacity (number of instances)')
@minValue(1)
@maxValue(32)
param capacity int = 2

@description('Application Gateway subnet ID')
param appGwSubnetId string

@description('Public IP configuration')
param publicIpConfig object = {
  name: '${appGwName}-pip'
  allocationMethod: 'Static'
  sku: 'Standard'
  tier: 'Regional'
  zones: []
}

@description('Enable HTTP/2 support')
param enableHttp2 bool = true

@description('Frontend ports configuration')
param frontendPorts array = [
  {
    name: 'port_80'
    port: 80
  }
]

@description('Backend address pools configuration')
param backendAddressPools array = [
  {
    name: 'defaultBackendPool'
    backendAddresses: []
  }
]

@description('Backend HTTP settings configuration')
param backendHttpSettings array = [
  {
    name: 'defaultHttpSetting'
    port: 80
    protocol: 'Http'
    cookieBasedAffinity: 'Disabled'
    requestTimeout: 30
    pickHostNameFromBackendAddress: false
    probeName: null
  }
]

@description('HTTP listeners configuration')
param httpListeners array = [
  {
    name: 'defaultListener'
    frontendIPConfigurationName: 'appGwPublicFrontendIp'
    frontendPortName: 'port_80'
    protocol: 'Http'
    requireServerNameIndication: false
    hostName: null
    sslCertificateName: null
  }
]

@description('Request routing rules configuration')
param requestRoutingRules array = [
  {
    name: 'defaultRoutingRule'
    ruleType: 'Basic'
    priority: 100
    httpListenerName: 'defaultListener'
    backendAddressPoolName: 'defaultBackendPool'
    backendHttpSettingsName: 'defaultHttpSetting'
  }
]

@description('Health probes configuration')
param probes array = []

@description('SSL certificates configuration')
param sslCertificates array = []

@description('Web Application Firewall configuration')
param wafConfig object = {
  enabled: true
  firewallMode: 'Prevention'
  ruleSetType: 'OWASP'
  ruleSetVersion: '3.2'
  disabledRuleGroups: []
  requestBodyCheck: true
  maxRequestBodySizeInKb: 128
  fileUploadLimitInMb: 100
  exclusions: []
}

@description('Enable availability zones')
param zones array = []

@description('Autoscale configuration')
param autoscaleConfig object = {
  enabled: false
  minCapacity: 1
  maxCapacity: 10
}

// Create a public IP address for the Application Gateway
resource publicIp 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: publicIpConfig.name
  location: location
  sku: {
    name: publicIpConfig.sku
    tier: publicIpConfig.tier
  }
  zones: !empty(publicIpConfig.zones) ? publicIpConfig.zones : null
  properties: {
    publicIPAllocationMethod: publicIpConfig.allocationMethod
  }
  tags: tags
}

// Create Application Gateway
resource appGw 'Microsoft.Network/applicationGateways@2023-05-01' = {
  name: appGwName
  location: location
  zones: !empty(zones) ? zones : null
  tags: tags
  properties: {
    sku: {
      name: sku
      tier: sku
      capacity: autoscaleConfig.enabled ? null : capacity
    }
    enableHttp2: enableHttp2
    autoscaleConfiguration: autoscaleConfig.enabled ? {
      minCapacity: autoscaleConfig.minCapacity
      maxCapacity: autoscaleConfig.maxCapacity
    } : null
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
        name: 'appGwPublicFrontendIp'
        properties: {
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
    frontendPorts: [for port in frontendPorts: {
      name: port.name
      properties: {
        port: port.port
      }
    }]
    backendAddressPools: [for pool in backendAddressPools: {
      name: pool.name
      properties: {
        backendAddresses: pool.backendAddresses
      }
    }]
    backendHttpSettingsCollection: [for setting in backendHttpSettings: {
      name: setting.name
      properties: {
        port: setting.port
        protocol: setting.protocol
        cookieBasedAffinity: setting.cookieBasedAffinity
        requestTimeout: setting.requestTimeout
        pickHostNameFromBackendAddress: setting.pickHostNameFromBackendAddress
        probe: setting.probeName != null ? {
          id: resourceId('Microsoft.Network/applicationGateways/probes', appGwName, setting.probeName)
        } : null
      }
    }]
    httpListeners: [for listener in httpListeners: {
      name: listener.name
      properties: {
        frontendIPConfiguration: {
          id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appGwName, listener.frontendIPConfigurationName)
        }
        frontendPort: {
          id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appGwName, listener.frontendPortName)
        }
        protocol: listener.protocol
        requireServerNameIndication: listener.requireServerNameIndication ?? false
        hostName: listener.hostName ?? null
        sslCertificate: contains(listener, 'sslCertificateName') && listener.sslCertificateName != null ? {
          id: resourceId('Microsoft.Network/applicationGateways/sslCertificates', appGwName, listener.sslCertificateName)
        } : null
      }
    }]
    requestRoutingRules: [for rule in requestRoutingRules: {
      name: rule.name
      properties: {
        ruleType: rule.ruleType
        priority: rule.priority
        httpListener: {
          id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appGwName, rule.httpListenerName)
        }
        backendAddressPool: contains(rule, 'backendAddressPoolName') && rule.backendAddressPoolName != null ? {
          id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appGwName, rule.backendAddressPoolName)
        } : null
        backendHttpSettings: contains(rule, 'backendHttpSettingsName') && rule.backendHttpSettingsName != null ? {
          id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appGwName, rule.backendHttpSettingsName)
        } : null
      }
    }]
    probes: !empty(probes) ? probes : null
    sslCertificates: !empty(sslCertificates) ? sslCertificates : null
    webApplicationFirewallConfiguration: sku == 'WAF_v2' ? wafConfig : null
  }
}

// Outputs
output appGwId string = appGw.id
output appGwName string = appGw.name
output publicIpAddress string = publicIp.properties.ipAddress
output publicIpId string = publicIp.id
output frontendIPConfigurationId string = appGw.properties.frontendIPConfigurations[0].id
