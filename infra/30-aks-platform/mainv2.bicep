
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

// AKS VNET RULES

@description('Allow rules for the Network Security Group')
param appGwNsgAllowRules array = [
  {
    name: 'AllowGatewayManagerInbound' // Top-level name
    properties: {                     // Nested properties
      priority: 100
      direction: 'Inbound'
      access: 'Allow'
      protocol: 'Tcp'
      sourcePortRange: '*'
      sourceAddressPrefix: 'GatewayManager'
      destinationPortRange: '65200-65535'
      destinationAddressPrefix: '*'
    }
  }
  {
    name: 'AllowAzureLoadBalancerInbound'
    properties: {
      priority: 110
      direction: 'Inbound'
      access: 'Allow'
      protocol: '*' 
      sourcePortRange: '*'
      sourceAddressPrefix: 'AzureLoadBalancer'
      destinationPortRange: '*'
      destinationAddressPrefix: '*'
    }
  }
  {
    name: 'AllowHttpFromInternetInbound'
    properties: {
      priority: 200
      direction: 'Inbound'
      access: 'Allow'
      protocol: 'Tcp'
      sourcePortRange: '*'
      sourceAddressPrefix: 'Internet'
      destinationPortRange: '80'
      destinationAddressPrefix: '*'
    }
  }
]

@description('Deny rules for the Network Security Group')
param appGwNsgDenyRules array = []

// ========== APP GATEWAY PARAMETERS ==========
@description('Application Gateway SKU')
@allowed([
  'Standard_v2'
  'WAF_v2'
])
param appGwSku string = 'WAF_v2'

// ========== AZURE KUBERNETES SERVICES PARAMETERS ==========

@description('DNS prefix for the AKS cluster')
param dnsPrefix string = uniqueString(resourceGroup().id, 'aks')

@description('Kubernetes version for the AKS cluster')
param kubernetesVersion string = '1.28.5'

@description('System node pool name for the AKS cluster')
param systemNodePoolName string = 'systempool'

@description('System node pool VM size for the AKS cluster')
param systemNodePoolVmSize string = 'Standard_DS2_v2'

@description('System node pool minimum number of nodes for the AKS cluster')
param systemNodePoolMinCount int = 1

@description('System node pool maximum number of nodes for the AKS cluster')
param systemNodePoolMaxCount int = 3

@description('User node pool name for the AKS cluster')
param userNodePoolName string = 'userpool'

@description('User node pool VM size for the AKS cluster')
param userNodePoolVmSize string = 'Standard_DS2_v2'

@description('User node pool OS type for the AKS cluster')
param userNodePoolOsType string = 'Linux'

@description('User node pool minimum number of nodes for the AKS cluster')
param userNodePoolMinCount int = 1

@description('User node pool maximum number of nodes for the AKS cluster')
param userNodePoolMaxCount int = 3

@description('AKS Admin Group object IDs for the AKS cluster')
param aksAdminGroupObjectIds array = []

// Creates a map for the Federated Identity Credential
// This will define what UAMIs need to be created for the federated identity credentials
// and what Kubernetes Service Account and Namespace they will be linked to
@description('Array of configurations for federated identity credentials. Each object links a UAMI to a specific Kubernetes Service Account and Namespace.')
param federationConfigs array = [
  {
    uamiTargetName: 'uami-securesharer-backend' 
    k8sServiceAccountName: 'secret-sharer-backend-sa'
    k8sNamespace: 'default' 
  }
  {
    uamiTargetName: 'uami-securesharer-db' 
    k8sServiceAccountName: 'secret-sharer-db-init-sa'
    k8sNamespace: 'default' 
  }
]

/*
 * =============================================================================
 * VARIABLES
 * =============================================================================
 */

// ========== NETWORK CONFIGURATION ==========

var addressSpace = [ '10.0.0.0/16' ]

var subnets  = [
  {
    name: 'snet-aks'
    addressPrefix: '10.0.1.0/24'
  }
  {
    name: 'snet-agw'
    addressPrefix: '10.0.2.0/24'
    nsgId: appGwNsg.outputs.nsgId
  }
  {
    name: 'snet-pe'
    addressPrefix: '10.0.3.0/24'
    privateEndpointNetworkPolicies: 'Disabled'
    nsgId: peNsg.outputs.nsgId
  }
]



/*
 * =============================================================================
 * RESOURCE NAMING MODULES
 * =============================================================================
 */

// ========== STANDARDIZED TAGGING ==========

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

// ========== RESOURCE NAMING ==========
module appGwNsgNamingModule '../40-modules/core/naming.bicep' = {
  name: 'appgw-nsg-naming'
  scope: subscription()
  params: {
    projectCode: projectCode
    environment: environmentName
    serviceCode: serviceCode
    resourceType: 'nsg'
  }
}

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

module acrNamingModule '../40-modules/core/naming.bicep' = {
  name: 'acr-naming'
  scope: subscription()
  params: {
    projectCode: projectCode
    environment: environmentName
    serviceCode: serviceCode
    resourceType: 'acr'
  }
}


module cosmosNamingModule '../40-modules/core/naming.bicep' = {
  name: 'cosmos-naming'
  scope: subscription()
  params: {
    projectCode: projectCode
    environment: environmentName
    serviceCode: serviceCode
    resourceType: 'cosmos'
  }
}

module aksNamingModule '../40-modules/core/naming.bicep' = {
  name: 'aks-naming'
  scope: subscription()
  params: {
    projectCode: projectCode
    environment: environmentName
    serviceCode: serviceCode
    resourceType: 'aks'
  }
}

module appGwNamingModule '../40-modules/core/naming.bicep' = {
  name: 'appgw-naming'
  scope: subscription()
  params: {
    projectCode: projectCode
    environment: environmentName
    serviceCode: serviceCode
    resourceType: 'agw'
  }
}

module appGwPipNamingModule '../40-modules/core/naming.bicep' = {
  name: 'appgw-pip-naming'
  scope: subscription()
  params: {
    projectCode: projectCode
    environment: environmentName
    serviceCode: serviceCode
    resourceType: 'pip'
  }
}

/*
 * =============================================================================
 * CORE INFRASTRUCTURE MODULES
 * =============================================================================
 */

/*
 * =============================================================================
 * NETWORK SECURITY GROUPS
 * =============================================================================
 */

// ========== APP GW SUBNET NSG ==========

module appGwNsg '../40-modules/core/nsg.bicep' = {
  name: 'appGwNsg'
  params: {
    nsgName: appGwNsgNamingModule.outputs.resourceName
    tags: standardTagsModule.outputs.tags
    allowRules: appGwNsgAllowRules
    denyRules: appGwNsgDenyRules
    location: resourceLocation
  }
}

// ========== PRIVATE ENDPOINTS SUBNET NSG ==========

var peAllowRules = [
  {
    name: 'AllowFromAKS'
    properties: {
      priority: 100
      direction: 'Inbound'
      access: 'Allow'
      protocol: 'Tcp'
      sourceAddressPrefix: '10.0.1.0/23'
      sourcePortRange: '*'
      destinationAddressPrefix: '10.0.3.0/24'
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


// ========== NETWORK DEPLOYMENT ==========

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

/*
 * =============================================================================
 * PLATFORM SERVICES DEPLOYMENT
 * =============================================================================
 */

// ========== KEY VAULT DEPLOYMENT ==========

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

// ========== KEY VAULT PRIVATE ENDPOINT ==========

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

// ========== AZURE CONTAINER REGISTRY DEPLOYMENT ==========

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

// ========== ACR PRIVATE ENDPOINT ==========

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

module cosmosDb '../40-modules/core/cosmos-db.bicep' = {
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
    privateEndpointName:       'pe-${cosmosDb.outputs.cosmosDbAccountName}'
    privateEndpointLocation:   resourceLocation
    privateEndpointSubnetId:   network.outputs.subnetIds[1]
    privateEndpointGroupId:    'Sql'
    privateEndpointServiceId:  cosmosDb.outputs.cosmosDbAccountId
    privateEndpointTags:       standardTagsModule.outputs.tags
    privateDnsZoneIds:         [ cosmosDns.outputs.privateDnsZoneId ]
  }
}

// ========== APP GW  DEPLOYMENT ==========
// Creates AppGW. Assumes subnet for appGW is in place [1] on array.
module appGw '../40-modules/aks/appgw.bicep' = {
  name: 'appgw'
  params: {
    appGwName: appGwNamingModule.outputs.resourceName
    location: resourceLocation
    tags: standardTagsModule.outputs.tags
    sku: appGwSku
    publicIpName: appGwPipNamingModule.outputs.resourceName
    appGwSubnetId: network.outputs.subnetIds[1]
  }
}


// =========== AKS DEPLOYMENT ==========

module aks '../40-modules/aks/aks.bicep' = {
  name: 'aks'
  params: {    
    location: resourceLocation
    tags: standardTagsModule.outputs.tags
    aksAdminGroupObjectIds: aksAdminGroupObjectIds
    aksName: aksNamingModule.outputs.resourceName
    dnsPrefix: dnsPrefix
    kubernetesVersion: kubernetesVersion
    systemNodePoolName: systemNodePoolName
    systemNodePoolVmSize: systemNodePoolVmSize
    systemNodePoolMinCount: systemNodePoolMinCount
    systemNodePoolMaxCount: systemNodePoolMaxCount
    userNodePoolName: userNodePoolName
    userNodePoolVmSize: userNodePoolVmSize
    userNodePoolOsType: userNodePoolOsType
    userNodePoolMinCount: userNodePoolMinCount
    userNodePoolMaxCount: userNodePoolMaxCount
    aksSubnetId: network.outputs.subnetIds[0]
    applicationGatewayIdForAgic: appGw.outputs.appGwId 
  }
}

// ========== UAMI DEPLOYMENTS ==========

// Creation of the UAMI and Federated Identity Credentials
// These modules creates the UAMIs and the Federated Identity Credentials

// Retrieves the names of the UAMIs from the federationConfigs parameter
var uamiNames = [for config in federationConfigs: config.uamiTargetName]

module uami '../40-modules/core/uami.bicep' = {
  name: 'uami'
  params: {
    uamiLocation: resourceLocation
    uamiNames: uamiNames
    tags: standardTagsModule.outputs.tags
  }
}

module federation '../40-modules/aks/federation.bicep' = [for config in federationConfigs: {
  name: 'fed-${take(uniqueString(config.uamiTargetName, config.k8sServiceAccountName), 13)}'
  params: {
    parentUserAssignedIdentityName: config.uamiTargetName
    serviceAccountName: config.k8sServiceAccountName
    serviceAccountNamespace: config.k8sNamespace
    oidcIssuerUrl: aks.outputs.oidcIssuerUrl
  }
}]

// Role Assignmeents for RBAC 

// This needs to be totally refactored to use /core/rbacs modules

// module rbac '../40-modules/aks/rbac.bicep' = {
//   name: 'rbac'
//   scope: rg
//   params: {
//     keyVaultId: akv.outputs.keyvaultId
//     acrId: acr.id
//     uamiIds: uami.outputs.uamiPrincipalIds 
//     aksId: aks.outputs.aksId
//     appGwId: appGw.outputs.appGwId
//     vnetId: network.outputs.vnetId
//     cosmosDbAccountId: cosmosDbAccountId
//   }
// }

/*
 * =============================================================================
 * OUTPUTS
 * =============================================================================
 */

// ========== CORE PLATFORM OUTPUTS ==========

output acrLoginServer string = acr.outputs.acrLoginServer
output acrName string = acr.name
output aksName string = aks.outputs.aksName
output backendK8sServiceAccountName string = federationConfigs[0].k8sServiceAccountName
output databaseInitK8sServiceAccountName string = federationConfigs[1].k8sServiceAccountName
output keyvaultName string = akv.outputs.keyvaultName
output appGwPublicIp string = appGw.outputs.publicIpAddress
output backendUamiClientId string = uami.outputs.uamis[0].clientId  // Backend UAMI
output dbInitUamiClientId string = uami.outputs.uamis[1].clientId  // DB Init UAMI
output tenantId string = tenantId
output cosmosDbAccountName string = cosmosDb.outputs.cosmosDbAccountName
output cosmosDatabaseName string = cosmosDb.outputs.databases[0].name
output cosmosContainerName string = cosmosDb.outputs.databases[0].containers[0].name
