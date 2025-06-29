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
param serviceCode string 

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

@description('List of User-Assigned Managed Identities to create. Each item can optionally include federation details.')
param managedIdentities array = [
  {
    uamiName: 'backend'
    federation: {
      k8sServiceAccountName: 'secret-sharer-backend-sa'
      k8sNamespace: 'default'
    }
  }
  {
    uamiName: 'kubelet'
  }
  {
    uamiName: 'aks-cluster'  // Add AKS cluster identity
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

module standardTagsModule '../modules/shared/tagging.bicep' = {
  scope: subscription()
  name: 'standard-tags-platform'
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
module appGwNsgNamingModule '../modules/shared/naming.bicep' = {
  name: 'appgw-nsg-naming'
  scope: subscription()
  params: {
    projectCode: projectCode
    environment: environmentName
    serviceCode: serviceCode
    resourceType: 'nsg'
  }
}

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

module aksNamingModule '../modules/shared/naming.bicep' = {
  name: 'aks-naming'
  scope: subscription()
  params: {
    projectCode: projectCode
    environment: environmentName
    serviceCode: serviceCode
    resourceType: 'aks'
  }
}

module appGwNamingModule '../modules/shared/naming.bicep' = {
  name: 'appgw-naming'
  scope: subscription()
  params: {
    projectCode: projectCode
    environment: environmentName
    serviceCode: serviceCode
    resourceType: 'agw'
  }
}

module appGwPipNamingModule '../modules/shared/naming.bicep' = {
  name: 'appgw-pip-naming'
  scope: subscription()
  params: {
    projectCode: projectCode
    environment: environmentName
    serviceCode: serviceCode
    resourceType: 'pip'
  }
}

module uamiNamingModules '../modules/shared/naming.bicep' = [
  for (item, i) in managedIdentities: {
    name: 'uami-naming-${item.uamiName}'
    scope: subscription()
    params: {
      projectCode: projectCode
      environment: environmentName
      serviceCode: serviceCode
      resourceType: 'id'
      suffix: 'k8s-${item.uamiName}'
    }
  }
]


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

module appGwNsg '../modules/networking/nsg.bicep' = {
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
      sourceAddressPrefix: '10.0.1.0/24'
      sourcePortRange: '*'
      destinationAddressPrefix: '10.0.3.0/24'
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
    privateEndpointSubnetId:     network.outputs.subnetIds[2]
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
    privateEndpointSubnetId:   network.outputs.subnetIds[2]
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
    privateEndpointSubnetId:   network.outputs.subnetIds[2]
    privateEndpointGroupId:    'Sql'
    privateEndpointServiceId:  cosmosDb.outputs.cosmosDbAccountId
    privateEndpointTags:       standardTagsModule.outputs.tags
    privateDnsZoneIds:         [ cosmosDns.outputs.privateDnsZoneId ]
  }
}

// ========== APP GW  DEPLOYMENT ==========
// Creates AppGW. Assumes subnet for appGW is in place [1] on array.
// module appGw '../40-modules/aks/appgw.bicep' = {
//   name: 'appgw'
//   params: {
//     appGwName: appGwNamingModule.outputs.resourceName
//     location: resourceLocation
//     tags: standardTagsModule.outputs.tags
//     sku: appGwSku
//     publicIpName: appGwPipNamingModule.outputs.resourceName
//     appGwSubnetId: network.outputs.subnetIds[1]
//   }
// }

module appGw '../modules/networking/appgw.bicep' = {
  name: 'appgw'
  params: {
    appGwName: appGwNamingModule.outputs.resourceName
    location: resourceLocation
    tags: standardTagsModule.outputs.tags
    sku: appGwSku
    appGwSubnetId: network.outputs.subnetIds[1]
    
    // Public IP configuration
    publicIpConfig: {
      name: appGwPipNamingModule.outputs.resourceName
      allocationMethod: 'Static'
      sku: 'Standard'
      tier: 'Regional'
      zones: []
    }
    
    // Optional: explicitly set other parameters to match old behavior
    capacity: 1
    enableHttp2: true
    
    
    // WAF configuration (will be applied if sku is WAF_v2)
    wafConfig: {
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
  }
}

// ========== UAMI DEPLOYMENTS ==========

// Creation of the UAMI and Federated Identity Credentials
// These modules creates the UAMIs and the Federated Identity Credentials

module uami '../modules/identity/uami.bicep' = {
  name: 'uami-aks'
  params: {
    uamiLocation: resourceLocation  
    uamiNames: [for i in range(0, length(managedIdentities)): uamiNamingModules[i].outputs.resourceName]
    tags: standardTagsModule.outputs.tags
  }
}

module federationConfigs '../modules/identity/k8s-federation.bicep' = [
  for (mi,i) in managedIdentities: if (contains(mi, 'federation')) {
    name: 'fed-${take(uniqueString(mi.uamiName, mi.federation.k8sServiceAccountName), 13)}'
    params: {
      parentUserAssignedIdentityName: uami.outputs.uamis[i].name
      serviceAccountName: mi.federation.k8sServiceAccountName
      serviceAccountNamespace: mi.federation.k8sNamespace
      oidcIssuerUrl: aks.outputs.oidcIssuerUrl
    }
  }
]


// Role Assignmeents for RBAC 

// Key Vault RBAC assignment
module rbacKv '../modules/identity/rbacKv.bicep' = {
  name: 'rbac-kv'
  params: {
    keyVaultId: akv.outputs.keyvaultId
    principalId: uami.outputs.uamis[0].principalId
    roleDefinitionId: '4633458b-17de-408a-b874-0445c86b69e6' // Key Vault Secrets User
  }
}

// ACR RBAC assignment
module rbacAcr '../modules/identity/rbacAcr.bicep' = {
  name: 'rbac-acr'
  params: {
    registryId: acr.outputs.acrId
    principalId: uami.outputs.uamis[1].principalId  // Updated index: Kubelet UAMI
    roleDefinitionId: '7f951dda-4ed3-4680-a7ca-43fe172d538d' // AcrPull
  }
}

// Cosmos DB RBAC assignment
module rbacCosmos '../modules/identity/rbacCosmos.bicep' = {
  name: 'rbac-cosmos'
  params: {
    accountName: cosmosDb.outputs.cosmosDbAccountName
    principalId: uami.outputs.uamis[0].principalId
    roleDefinitionId: '00000000-0000-0000-0000-000000000002' // Cosmos DB Built-in Data Contributor
  }
}

module rbacAksKubeletOperator '../modules/identity/rbacUami.bicep' = {
  name: 'rbac-aks-kubelet-operator'
  params: {
    uamiName: uami.outputs.uamis[1].name  // Updated index: Kubelet UAMI resource name
    principalId: uami.outputs.uamis[2].principalId  // Updated index: AKS control plane identity
    roleDefinitionId: 'f1a07417-d97a-45cb-824c-7a7467783830'  // Managed Identity Operator
  }
}

// =========== AKS DEPLOYMENT ==========

module aks '../modules/container/aks.bicep' = {
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
    // NOTE: Azure AKS ignores agicUserAssignedIdentityId parameter due to platform bug
    // AGIC addon auto-creates its own identity regardless of this setting
    agicUserAssignedIdentityId: null // Not used - AKS creates its own AGIC identity
    kubeletUserAssignedIdentityId: uami.outputs.uamis[1].id // Updated index: Kubelet UAMI
    identityType: 'UserAssigned'  // Change from SystemAssigned to UserAssigned
    userAssignedIdentities: [uami.outputs.uamis[2].id]  // Updated index: AKS cluster identity
  }
}

// =========== POST-AKS RBAC ASSIGNMENTS FOR AUTO-CREATED AGIC IDENTITY ==========
// These must run AFTER AKS deployment since the AGIC identity is created during AKS deployment

// Resource Group Reader RBAC assignment for AGIC
module rbacRgAgic '../modules/identity/rbacRg.bicep' = {
  name: 'rbac-rg-reader-agic'
  scope: resourceGroup()
  params: {
    principalId: aks.outputs.agicIdentityPrincipalId // Auto-created AGIC identity
    roleDefinitionId: 'acdd72a7-3385-48ef-bd42-f606fba81ae7' // Reader
  }
}

// App Gateway RBAC assignment for AGIC
module rbacAppGwAgic '../modules/identity/rbacAppGw.bicep' = {
  name: 'rbac-appgw-agic'
  params: {
    appGwId: appGw.outputs.appGwId
    principalId: aks.outputs.agicIdentityPrincipalId // Auto-created AGIC identity
    roleDefinitionId: 'b24988ac-6180-42a0-ab88-20f7382dd24c' // Contributor
  }
}

// VNet RBAC assignment for AGIC
module rbacVnetAgic '../modules/identity/rbacVnet.bicep' = {
  name: 'rbac-vnet-agic'
  params: {
    vnetId: network.outputs.vnetId
    principalId: aks.outputs.agicIdentityPrincipalId // Auto-created AGIC identity
    roleDefinitionId: '4d97b98b-1d4f-4787-a291-c67834d212e7' // Network Contributor
  }
}


/*
 * =============================================================================
 * OUTPUTS
 * =============================================================================
 */

// ========== CORE PLATFORM OUTPUTS ==========

output acrLoginServer string = acr.outputs.acrLoginServer
output acrName string = acr.name
output aksName string = aks.outputs.aksName
output keyvaultName string = akv.outputs.keyvaultName
output appGwPublicIp string = appGw.outputs.publicIpAddress
output backendUamiClientId string = uami.outputs.uamis[0].clientId  // Backend UAMI
output backendK8sServiceAccountName string = managedIdentities[0].federation.k8sServiceAccountName
output tenantId string = tenantId
output cosmosDbAccountName string = cosmosDb.outputs.cosmosDbAccountName
output cosmosDatabaseName string = cosmosDb.outputs.databases[0].name
output cosmosContainerName string = cosmosDb.outputs.databases[0].containers[0].name
