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
 * │  │ ┌─────────────────────┐                                          ││
 * │  │ │ Container Apps      │                                          ││
 * │  │ │ Environment         │                                          ││
 * │  │ │ • Backend Services  │                                          ││
 * │  │ │ • API Endpoints     │                                          ││
 * │  │ └─────────────────────┘                                          ││
 * │  │                                                                    ││
 * │  │ Private Endpoints Subnet (10.0.30.0/24)                          ││
 * │  │ ┌─────────────────────┐  ┌─────────────────────────────────────┐  ││
 * │  │ │ Key Vault PE        │  │ Cosmos DB PE                        │  ││
 * │  │ │ Container Registry  │  │ Log Analytics PE                    │  ││
 * │  │ │ PE                  │  │                                     │  ││
 * │  │ └─────────────────────┘  └─────────────────────────────────────┘  ││
 * │  └─────────────────────────────────────────────────────────────────────┘│
 * │                                                                         │
 * │  External Services (Connected via Internet):                           │
 * │  • Static Web Apps (Global CDN) - Frontend hosting                     │
 * │  • GitHub Actions - CI/CD with federated authentication               │
 * │  • Azure services accessible via private endpoints                     │
 * └─────────────────────────────────────────────────────────────────────────┘
 * 
 * KEY FEATURES:
 * • Comprehensive Platform: Complete infrastructure with networking and security
 * • Container Apps Environment: Managed serverless container platform for backend APIs
 * • Private Connectivity: Secure access to shared services via private endpoints
 * • Network Segmentation: Dedicated subnets for different service types
 * • Centralized Monitoring: Log Analytics integration for platform observability
 * • Security Best Practices: Network security groups and private endpoint protection
 * • Shared Services: Container Registry, Cosmos DB, and Key Vault with private access
 * 
 * SECURITY CONSIDERATIONS:
 * • Network isolation through dedicated virtual network and subnets
 * • Private endpoint connectivity to shared services (ACR, Cosmos DB, Key Vault)
 * • Network Security Groups with restrictive rules for each subnet
 * • Secure backend API hosting in Container Apps with network protection
 * • Centralized secret management through Key Vault with private access
 * • Comprehensive audit logging through Log Analytics workspace integration
 * 
 * DEPLOYMENT SCOPE:
 * This template operates at resource group scope to create platform
 * infrastructure that hosts Container Apps backend services while providing
 * secure connectivity to shared services via private endpoints.
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


// ========== AZURE CONTAINER REGISTRY PARAMETERS ==========

@description('SKU tier for Azure Container Registry - Premium recommended for production workloads')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param acrSku string = 'Premium'

@description('Enable admin user for Azure Container Registry - disabled by default for security')
param acrEnableAdminUser bool = false

// ========== COSMOS DB PARAMETERS ==========

@description('Cosmos DB database and container configuration for multi-environment support')
param cosmosDbConfig array 

@description('Enable Cosmos DB free tier - not supported on internal/enterprise subscriptions')
param cosmosEnableFreeTier bool = false

// ========== KEY VAULT PARAMETERS ==========

@description('Key Vault SKU tier - standard or premium')
@allowed([ 'standard', 'premium' ])
param akvSku string = 'standard'

@description('Enable RBAC on Key Vault for access control')
param akvRbac bool = true

@description('Enable purge protection on Key Vault for security')
param akvPurgeProtection bool = true

@description('Secrets to store in Key Vault')
@secure()
param akvSecrets object



/*
 * =============================================================================
 * VARIABLES
 * =============================================================================
 */

// ========== NETWORK CONFIGURATION ==========

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

/*
 * =============================================================================
 * CORE INFRASTRUCTURE MODULES
 * =============================================================================
 */

// ========== NETWORK DEPLOYMENT ==========

module network '../modules/networking/network.bicep' = {
  name:  'network'
  params: {
    vnetName:      vnetNamingModule.outputs.resourceName
    location:      resourceLocation
    addressSpace:  addressSpace
    subnets:       subnets
    tags:          standardTagsModule.outputs.tags
  }
}

/*
 * =============================================================================
 * RESOURCE NAMING MODULES
 * =============================================================================
 */

// ========== STANDARDIZED TAGGING ==========

module standardTagsModule '../modules/shared/tagging.bicep' = {
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

// ========== RESOURCE NAMING ==========

module vnetNamingModule '../modules/shared/naming.bicep' = {
  scope: subscription()
  name: 'vnet-naming'
  params: {
    projectCode: projectCode
    environment: environmentName
    serviceCode: serviceCode
    resourceType: 'vnet'
  }
}

module akvNamingModule '../modules/shared/naming.bicep' = {
  scope: subscription()
  name: 'akv-naming'
  params: {
    projectCode: projectCode
    environment: environmentName
    serviceCode: serviceCode
    resourceType: 'kv'
  }
}

module lawNamingModule '../modules/shared/naming.bicep' = {
  scope: subscription()
  name: 'law-naming'
  params: {
    projectCode: projectCode
    environment: environmentName
    serviceCode: serviceCode
    resourceType: 'log'
  }
}

module acaEnvNamingModule '../modules/shared/naming.bicep' = {
  scope: subscription()
  name: 'aca-env-naming'
  params: {    
    projectCode: projectCode
    environment: environmentName
    serviceCode: serviceCode
    resourceType: 'cae'
  }
}

module acaNsgNamingModule '../modules/shared/naming.bicep' = {
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

module peNsgNamingModule '../modules/shared/naming.bicep' = {
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

module acrNamingModule '../modules/shared/naming.bicep' = {
  name: 'acr-naming'
  scope: subscription()
  params: {
    projectCode: projectCode
    environment: environmentName
    serviceCode: serviceCode
    resourceType: 'acr'
  }
}

module cosmosNamingModule '../modules/shared/naming.bicep' = {
  name: 'cosmos-naming'
  scope: subscription()
  params: {
    projectCode: projectCode
    environment: environmentName
    serviceCode: serviceCode
    resourceType: 'cosmos'
  }
}



/*
 * =============================================================================
 * PLATFORM SERVICES DEPLOYMENT
 * =============================================================================
 */

// ========== KEY VAULT DEPLOYMENT ==========

module akv '../modules/security/keyvault.bicep' = {
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

// ========== KEY VAULT PRIVATE ENDPOINT ==========

module kvDns '../modules/networking/private-dns-zone.bicep' = {
  name:  'kvPrivateDns'
  params: {
    privateDnsZoneName:  'privatelink.vaultcore.azure.net'
    vnetId:              network.outputs.vnetId
    privateDnsZoneTags:  standardTagsModule.outputs.tags
  }
}

module kvPe '../modules/networking/private-endpoint.bicep' = {
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

// ========== AZURE CONTAINER REGISTRY DEPLOYMENT ==========

module acr '../modules/container/acr.bicep' = {
  name: 'acr'
  params: {
    tags: standardTagsModule.outputs.tags
    acrName: acrNamingModule.outputs.resourceName
    location: resourceLocation
    sku: acrSku
    enableAdminUser: acrEnableAdminUser
  }
}

// ========== ACR PRIVATE ENDPOINT ==========

module acrDns '../modules/networking/private-dns-zone.bicep' = {
  name:  'acrPrivateDns'
  params: {
    privateDnsZoneName:  'privatelink.azurecr.io'
    vnetId:              network.outputs.vnetId
    privateDnsZoneTags:  standardTagsModule.outputs.tags
  }
}

module acrPe '../modules/networking/private-endpoint.bicep' = {
  name:  'acrPrivateEndpoint'
  params: {
    privateEndpointName:       'pe-${acr.outputs.acrName}'
    privateEndpointLocation:   resourceLocation
    privateEndpointSubnetId:   network.outputs.subnetIds[1]
    privateEndpointGroupId:    'registry'
    privateEndpointServiceId:  acr.outputs.acrId
    privateEndpointTags:       standardTagsModule.outputs.tags
    privateDnsZoneIds:         [ acrDns.outputs.privateDnsZoneId ]
  }
}

// ========== COSMOS DB DEPLOYMENT ==========

module cosmosDb '../modules/database/cosmos-db.bicep' = {
  name: 'deploy-cosmos-db'
  params: {
    cosmosDbAccountName: cosmosNamingModule.outputs.resourceName
    location: resourceLocation
    databases: cosmosDbConfig
    tags: standardTagsModule.outputs.tags
    enableFreeTier: cosmosEnableFreeTier
  }
}

// ========== COSMOS DB PRIVATE ENDPOINT ==========

module cosmosDns '../modules/networking/private-dns-zone.bicep' = {
  name:  'cosmosPrivateDns'
  params: {
    privateDnsZoneName:  'privatelink.documents.azure.com'
    vnetId:              network.outputs.vnetId
    privateDnsZoneTags:  standardTagsModule.outputs.tags
  }
}

module cosmosPe '../modules/networking/private-endpoint.bicep' = {
  name:  'cosmosPrivateEndpoint'
  params: {
    privateEndpointName:       'pe-${cosmosDb.outputs.cosmosDbAccountName}'
    privateEndpointLocation:   resourceLocation
    privateEndpointSubnetId:   network.outputs.subnetIds[1]
    privateEndpointGroupId:    'Sql'
    privateEndpointServiceId:  cosmosDb.outputs.cosmosDbAccountId
    privateEndpointTags:       standardTagsModule.outputs.tags
    privateDnsZoneIds:         [ cosmosDns.outputs.privateDnsZoneId ]
  }
}

// ========== LOG ANALYTICS WORKSPACE DEPLOYMENT ==========

module workspace '../modules/monitoring/log-analytics-workspace.bicep' = {
  name:  'workspace'
  params: {
    workspaceName: lawNamingModule.outputs.resourceName
    location:      resourceLocation
    tags:          standardTagsModule.outputs.tags
  }
}

// ========== CONTAINER APPS ENVIRONMENT DEPLOYMENT ==========

module acaEnv '../modules/container/aca-environment.bicep' = {
  name:  'acaEnvironment'
  params: {
    acaEnvironmentName: acaEnvNamingModule.outputs.resourceName
    acaEnvironmentLocation: resourceLocation
    acaEnvironmentTags: standardTagsModule.outputs.tags
    workspaceId: workspace.outputs.workspaceId
    acaEnvironmentSubnetId: network.outputs.subnetIds[0]
  }
}

/*
 * =============================================================================
 * NETWORK SECURITY GROUPS
 * =============================================================================
 */

// ========== CONTAINER APPS SUBNET NSG ==========

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

module acaNsg '../modules/networking/nsg.bicep' = {
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

// ========== PRIVATE ENDPOINTS SUBNET NSG ==========

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

module peNsg '../modules/networking/nsg.bicep' = {
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

/*
 * =============================================================================
 * OUTPUTS
 * =============================================================================
 */

// ========== CORE PLATFORM OUTPUTS ==========

@description('Container Apps environment resource ID')
output caeEnvironmentId      string = acaEnv.outputs.acaEnvironmentId

@description('Container Apps environment resource name')
output caeEnvironmentName    string = last(split(acaEnv.outputs.acaEnvironmentId, '/'))

@description('Container Apps default domain for the environment')
output caeDefaultDomain      string = acaEnv.outputs.acaDefaultDomain

@description('Key Vault URI for secret management')
output keyVaultUri           string = akv.outputs.keyvaultUri

@description('Network Security Group ID for Container Apps subnet')
output acaNsgId              string = acaNsg.outputs.nsgId

@description('Network Security Group ID for Private Endpoints subnet')
output peNsgId               string = peNsg.outputs.nsgId

// ========== CONTAINER REGISTRY OUTPUTS ==========

@description('Azure Container Registry name for image storage and distribution')
output acrName string = acr.outputs.acrName

@description('Azure Container Registry login server URL for Docker operations')
output acrLoginServer string = acr.outputs.acrLoginServer

// ========== COSMOS DB OUTPUTS ==========

@description('Cosmos DB account endpoint URL for database connectivity')
output cosmosDbEndpoint string = cosmosDb.outputs.cosmosDbEndpoint

@description('Cosmos DB account name for configuration and access control')
output cosmosDbAccountName string = cosmosDb.outputs.cosmosDbAccountName

@description('Array of created Cosmos DB databases with configuration details')
output cosmosDbDatabases array = cosmosDb.outputs.databases
