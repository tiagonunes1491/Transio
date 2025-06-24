/*
 * =============================================================================
 * SWA Platform Infrastructure for Secure Secret Sharer
 * =============================================================================
 * 
 * This Bicep template establishes the Static Web App (SWA) platform infrastructure
 * for the Secure Secret Sharer application. It creates a comprehensive platform
 * environment that supports both Container Apps and Static Web Apps with secure
 * networking, identity management, and monitoring capabilities.
 * 
 * ARCHITECTURE OVERVIEW:
 * ┌─────────────────────────────────────────────────────────────────────────┐
 * │                       SWA Platform Infrastructure                       │
 * ├─────────────────────────────────────────────────────────────────────────┤
 * │  Virtual Network (10.0.0.0/16)                                         │
 * │  ┌─────────────────────────────────────────────────────────────────────┐│
 * │  │ Container Apps Subnet (10.0.10.0/23)                              ││
 * │  │ ┌─────────────────────┐  ┌─────────────────────────────────────┐  ││
 * │  │ │ Container Apps      │  │ Static Web Apps                     │  ││
 * │  │ │ Environment         │  │ Frontend Applications               │  ││
 * │  │ │                     │  │                                     │  ││
 * │  │ └─────────────────────┘  └─────────────────────────────────────┘  ││
 * │  │                                                                    ││
 * │  │ Private Endpoints Subnet (10.0.30.0/24)                          ││
 * │  │ ┌─────────────────────┐  ┌─────────────────────────────────────┐  ││
 * │  │ │ Key Vault PE        │  │ Cosmos DB PE                        │  ││
 * │  │ │ Log Analytics PE    │  │ Container Registry PE               │  ││
 * │  │ └─────────────────────┘  └─────────────────────────────────────┘  ││
 * │  └─────────────────────────────────────────────────────────────────────┘│
 * │                                                                         │
 * │  Supporting Services:                                                   │
 * │  • User-Assigned Managed Identity with federated credentials           │
 * │  • Key Vault for secure secrets management                             │
 * │  • Log Analytics workspace for monitoring and observability            │
 * │  • Network Security Groups with appropriate access controls            │
 * └─────────────────────────────────────────────────────────────────────────┘
 * 
 * KEY FEATURES:
 * • Comprehensive Platform: Complete SWA/ACA platform with networking and security
 * • Container Apps Environment: Managed serverless container platform
 * • Static Web Apps: Frontend hosting with global CDN and automatic scaling
 * • Private Connectivity: Secure access to shared services via private endpoints
 * • Network Segmentation: Dedicated subnets for different workload types
 * • Identity Integration: Managed identities with GitHub federation support
 * • Centralized Monitoring: Log Analytics integration for platform observability
 * • Security Best Practices: Network security groups and private endpoint protection
 * 
 * SECURITY CONSIDERATIONS:
 * • Network isolation through dedicated virtual network and subnets
 * • Private endpoint connectivity to shared services (ACR, Cosmos DB)
 * • Network Security Groups with restrictive rules for each subnet
 * • Managed identity-based authentication eliminating credential management
 * • GitHub federation for secure CI/CD workflows
 * • Key Vault integration for secure secret management
 * • Audit logging through Log Analytics workspace integration
 * 
 * DEPLOYMENT SCOPE:
 * This template operates at resource group scope to create platform
 * infrastructure that can host multiple SWA and Container Apps workloads
 * while maintaining secure connectivity to shared services.
 */
targetScope = 'resourceGroup'

/*
 * =============================================================================
 * PARAMETERS
 * =============================================================================
 */

// ========== CORE DEPLOYMENT PARAMETERS ==========

@description('Azure AD tenant ID for Key Vault authentication and managed identity federation')
param tenantId string = subscription().tenantId

@description('Azure region for all resource deployments')
param resourceLocation string = 'spaincentral'

@description('Short project identifier used in resource naming conventions')
param projectCode string = 'ss'

@description('Service identifier for this SWA/ACA platform deployment')
param serviceCode string = 'swa'

@description('Target environment for deployment affecting resource configuration and naming')
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

@description('Name of existing shared platform resource group containing ACR and Cosmos DB')
param sharedResourceGroupName string

@description('Name of existing Azure Container Registry for container image storage')
param acrName string

@description('Name of existing Cosmos DB account for database connectivity via private endpoints')
param cosmosDbAccountName string

// Reference existing ACR resource to get its ID and login server automatically
resource sssplatacr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: acrName
  scope: resourceGroup(subscription().subscriptionId, sharedResourceGroupName)
}

// Reference existing Cosmos DB account for private endpoint creation
resource cosmosDbAccount 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' existing = {
  name: cosmosDbAccountName
  scope: resourceGroup(subscription().subscriptionId, sharedResourceGroupName)
}


// ========== VNET & SUBNETS ==========
var addressSpace = [ '10.0.0.0/16' ]
var subnets = [
  {
    name:          'snet-aca'
    addressPrefix: '10.0.10.0/23'
    nsgId:         acaNsg.outputs.nsgId
  }
  {
    name:                             'snet-pe'
    addressPrefix:                    '10.0.30.0/24'
    privateEndpointNetworkPolicies:  'Disabled'
    nsgId:                           peNsg.outputs.nsgId
  }
]
module network '../40-modules/core/network.bicep' = {
  name:  'network'
  params: {
    vnetName:      vnetNamingModule.outputs.resourceName
    location:      resourceLocation
    addressSpace:  addressSpace
    subnets:       subnets
    tags:          standardTagsModule.outputs.tags
  }
}

// ========== NAMING AND TAGGING MODULES ==========

// Generate standardized tags using the tagging module
module standardTagsModule '../40-modules/core/tagging.bicep' = {
  scope: subscription()
  name: 'standard-tags-swa-platform'
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
module vnetNamingModule '../40-modules/core/naming.bicep' = {
  scope: subscription()
  name: 'vnet-naming'
  params: {
    projectCode: projectCode
    environment: environmentName
    serviceCode: serviceCode
    resourceType: 'vnet'
  }
}

module akvNamingModule '../40-modules/core/naming.bicep' = {
  scope: subscription()
  name: 'akv-naming'
  params: {
    projectCode: projectCode
    environment: environmentName
    serviceCode: serviceCode
    resourceType: 'kv'
  }
}

module lawNamingModule '../40-modules/core/naming.bicep' = {
  scope: subscription()
  name: 'law-naming'
  params: {
    projectCode: projectCode
    environment: environmentName
    serviceCode: serviceCode
    resourceType: 'log'
  }
}

module acaEnvNamingModule '../40-modules/core/naming.bicep' = {
  scope: subscription()
  name: 'aca-env-naming'
  params: {    
    projectCode: projectCode
    environment: environmentName
    serviceCode: serviceCode
    resourceType: 'cae'
  }
}

module acaNsgNamingModule '../40-modules/core/naming.bicep' = {
  scope: subscription()
  name: 'aca-nsg-naming'
  params: {    
    projectCode: projectCode
    environment: environmentName
    serviceCode: serviceCode
    resourceType: 'nsg'
    suffix: 'ca'
  }
}

module peNsgNamingModule '../40-modules/core/naming.bicep' = {
  scope: subscription()
  name: 'pe-nsg-naming'
  params: {    
    projectCode: projectCode
    environment: environmentName
    serviceCode: serviceCode
    resourceType: 'nsg'
    suffix: 'pe'
  }
}



// ========== KEY VAULT & PRIVATE ENDPOINT ==========
@description('Key Vault SKU')
@allowed([ 'standard', 'premium' ])
param akvSku string = 'standard'

@description('Enable RBAC on Key Vault')
param akvRbac bool = true

@description('Enable purge protection on Key Vault')
param akvPurgeProtection bool = true

@description('Secrets to store in Key Vault')
@secure()
param akvSecrets object

module akv '../40-modules/core/keyvault.bicep' = {
  name:  'keyvault'
  params: {
    keyvaultName:            akvNamingModule.outputs.resourceName
    location:                resourceLocation
    sku:                     akvSku
    tenantId:                tenantId
    enableRbac:              akvRbac
    enablePurgeProtection:   akvPurgeProtection
    secretsToSet:            akvSecrets
    tags:                    standardTagsModule.outputs.tags
  }
}

module kvDns '../40-modules/core/private-dns-zone.bicep' = {
  name:  'kvPrivateDns'
  params: {
    privateDnsZoneName:  'privatelink.vaultcore.azure.net'
    vnetId:              network.outputs.vnetId
    privateDnsZoneTags:  standardTagsModule.outputs.tags
  }
}

module kvPe '../40-modules/core/private-endpoint.bicep' = {
  name:  'kvPrivateEndpoint'
  params: {
    privateEndpointName:         'pe-${akv.outputs.keyvaultName}'
    privateEndpointLocation:     resourceLocation
    privateEndpointSubnetId:     network.outputs.subnetIds[1]
    privateEndpointGroupId:      'vault'
    privateEndpointServiceId:    akv.outputs.keyvaultId
    privateEndpointTags:         standardTagsModule.outputs.tags
    privateDnsZoneIds:           [ kvDns.outputs.privateDnsZoneId ]
  }
}

// ========== ACR PRIVATE ENDPOINT (existing shared ACR) ==========
module acrDns '../40-modules/core/private-dns-zone.bicep' = {
  name:  'acrPrivateDns'
  params: {
    privateDnsZoneName:  'privatelink.azurecr.io'
    vnetId:              network.outputs.vnetId
    privateDnsZoneTags:  standardTagsModule.outputs.tags
  }
}

module acrPe '../40-modules/core/private-endpoint.bicep' = {
  name:  'acrPrivateEndpoint'
  params: {
    privateEndpointName:       'pe-${acrName}'
    privateEndpointLocation:   resourceLocation
    privateEndpointSubnetId:   network.outputs.subnetIds[1]
    privateEndpointGroupId:    'registry'
    privateEndpointServiceId:  sssplatacr.id
    privateEndpointTags:       standardTagsModule.outputs.tags
    privateDnsZoneIds:         [ acrDns.outputs.privateDnsZoneId ]
  }
}

// ========== COSMOS DB PRIVATE ENDPOINT (existing shared Cosmos DB) ==========
module cosmosDns '../40-modules/core/private-dns-zone.bicep' = {
  name:  'cosmosPrivateDns'
  params: {
    privateDnsZoneName:  'privatelink.documents.azure.com'
    vnetId:              network.outputs.vnetId
    privateDnsZoneTags:  standardTagsModule.outputs.tags
  }
}

module cosmosPe '../40-modules/core/private-endpoint.bicep' = {
  name:  'cosmosPrivateEndpoint'
  params: {
    privateEndpointName:       'pe-${cosmosDbAccountName}'
    privateEndpointLocation:   resourceLocation
    privateEndpointSubnetId:   network.outputs.subnetIds[1]
    privateEndpointGroupId:    'Sql'
    privateEndpointServiceId:  cosmosDbAccount.id
    privateEndpointTags:       standardTagsModule.outputs.tags
    privateDnsZoneIds:         [ cosmosDns.outputs.privateDnsZoneId ]
  }
}

// ========== LOG ANALYTICS WORKSPACE ==========
module workspace '../40-modules/core/log-analytics-workspace.bicep' = {
  name:  'workspace'
  params: {
    workspaceName: lawNamingModule.outputs.resourceName
    location:      resourceLocation
    tags:          standardTagsModule.outputs.tags
  }
}

// ========== ACA ENVIRONMENT ==========
module acaEnv '../40-modules/core/aca-environment.bicep' = {
  name:  'acaEnvironment'
  params: {
    acaEnvironmentName: acaEnvNamingModule.outputs.resourceName
    acaEnvironmentLocation: resourceLocation
    acaEnvironmentTags: standardTagsModule.outputs.tags
    workspaceId: workspace.outputs.workspaceId
    acaEnvironmentSubnetId: network.outputs.subnetIds[0]
  }
}

// ========== NETWORK SECURITY GROUPS ==========

// NSG for Container Apps subnet (snet-aca)
var acaAllowRules = [
  {
    name: 'AllowStaticWebAppsInbound'
    properties: {
      priority: 100
      direction: 'Inbound'
      access: 'Allow'
      protocol: 'Tcp'
      sourceAddressPrefix: 'AzureCloud'
      sourcePortRange: '*'
      destinationAddressPrefix: '10.0.10.0/23'
      destinationPortRange: '443'
    }
  }
  {
    name: 'AllowPrivateEndpointsOutbound'
    properties: {
      priority: 100
      direction: 'Outbound'
      access: 'Allow'
      protocol: 'Tcp'
      sourceAddressPrefix: '10.0.10.0/23'
      sourcePortRange: '*'
      destinationAddressPrefix: '10.0.30.0/24'
      destinationPortRange: '443'
    }
  }
]

module acaNsg '../40-modules/core/nsg.bicep' = {
  name: 'acaNsg'
  params: {
    nsgName: acaNsgNamingModule.outputs.resourceName
    location: resourceLocation
    allowRules: acaAllowRules
    denyRules: []
    tags: standardTagsModule.outputs.tags
    includeDefaultDenyRule: true
  }
}

// NSG for Private Endpoints subnet (snet-pe)
var peAllowRules = [
  {
    name: 'AllowFromContainerApps'
    properties: {
      priority: 100
      direction: 'Inbound'
      access: 'Allow'
      protocol: 'Tcp'
      sourceAddressPrefix: '10.0.10.0/23'
      sourcePortRange: '*'
      destinationAddressPrefix: '10.0.30.0/24'
      destinationPortRange: '443'
    }
  }
]

module peNsg '../40-modules/core/nsg.bicep' = {
  name: 'peNsg'
  params: {
    nsgName: peNsgNamingModule.outputs.resourceName
    location: resourceLocation
    allowRules: peAllowRules
    denyRules: []
    tags: standardTagsModule.outputs.tags
    includeDefaultDenyRule: true
  }
}

// ========== OUTPUTS ==========
output acrName               string = acrName
output acrLoginServer        string = sssplatacr.properties.loginServer  // Get from existing resource
output caeEnvironmentId      string = acaEnv.outputs.acaEnvironmentId
output caeEnvironmentName    string = last(split(acaEnv.outputs.acaEnvironmentId, '/'))
output caeDefaultDomain      string = acaEnv.outputs.acaDefaultDomain
output keyVaultUri           string = akv.outputs.keyvaultUri
output acaNsgId              string = acaNsg.outputs.nsgId
output peNsgId               string = peNsg.outputs.nsgId
