targetScope = 'subscription'

@description('The Azure AD tenant ID that should be used for authenticating requests to the key vault. Defaults to the current subscription tenant ID.')
param tenantId string = subscription().tenantId

@description('Location for the resources')
param resourceLocation string = 'spaincentral'

@description('Name of the resource group')
param rgName string = 'rg-ssharer-k8s-spoke-dev'

@description('Tags for the resources')
param tags object = {
  environment: 'dev'
  project: 'secure-secret-sharer'
  owner: 'Tiago'
}

// Creates a map for the Federated Identity Credential
// This will define what UAMIs need to be created for the federated identity credentials
// and what Kubernetes Service Account and Namespace they will be linked to
// Test 01
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

// Use existing resource group from landing zone deployment
resource rg 'Microsoft.Resources/resourceGroups@2025-03-01' existing = {
  name: rgName
}

// NSG

@description('Name of the Network Security Group')
param appGwNsgName string = 'nsg-securesharer-mvp'

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


module appGwNsg 'aks-modules/nsg.bicep' = {
  name: appGwNsgName
  scope: rg
  params: {
    nsgName: appGwNsgName
    tags: tags
    allowRules: appGwNsgAllowRules
    denyRules: appGwNsgDenyRules
    location: resourceLocation
  }
}


// Deployment for VNET 
// ! Order of subnets are important and should not be changed.
// The first subnet is for the AKS cluster and the second one is for the Application Gateway.

@description('Name of the virtual network')
param vnetName string = 'vnet-secureSecretSharer'

@description('Address space for the virtual network')
var addressSpace  = [
  '10.0.0.0/16'
]

@description('Subnets for the virtual network')
var subnets  = [
  {
    name: 'snet-aks'
    addressPrefix: '10.0.1.0/24'
  }
    {
    name: 'snet-agw'
    addressPrefix: '10.0.2.0/24'
  }
]

module network 'common-modules/network.bicep' = {
  name: 'network'
  scope: rg
  params: {
    vnetName: vnetName
    location: resourceLocation
    addressSpace: addressSpace
    subnets: [
      for subnet in subnets: {
        name: subnet.name
        addressPrefix: subnet.addressPrefix
        networkSecurityGroupId: subnet.name == 'snet-agw'  ? appGwNsg.outputs.nsgId : null
      }
    ]
  }
}

// Deployment for ACR

@description('Azure Container Registry name')
param acrName string

@description('SKU for the ACR')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param acrSku string = 'Standard'

@description('Enable admin user for the ACR')
param acrEnableAdminUser bool = false

module acr 'shared-infra-modules/acr.bicep' = {
  name: 'acr'
  scope: rg
  params: {
    acrName: acrName
    location: resourceLocation
    sku: acrSku
    enableAdminUser: acrEnableAdminUser
  }
}

// Deployment for AKV

@minLength(3)
@maxLength(24)
@description('Name of the keyvault')
param akvName string = 'kv-sec-secret-sharer'

@description('SKU for the keyvault')
@allowed([
  'standard'
  'premium'
])
param akvSku string = 'standard'

@description('Enable rbac for the keyvault')
param akvRbac bool = true

@description('Enable purge protection for the keyvault')
param akvPurgeProtection bool = true

@description('Secure object for secrets')
@secure()
param akvSecrets object

module akv 'common-modules/keyvault.bicep' = {
  name: 'keyvault'
  scope: rg
  params: {
    keyvaultName: akvName
    location: resourceLocation
    tags: tags
    sku: akvSku
    tenantId: tenantId
    enableRbac: akvRbac
    enablePurgeProtection: akvPurgeProtection
    secretsToSet: akvSecrets
  }
}

// Deployment for AKS

@description('Name of the AKS cluster')
param aksName string = 'aks-securesharer-mvp'

@description('DNS prefix for the AKS cluster')
param dnsPrefix string = uniqueString(rgName, aksName)

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

module aks 'aks-modules/aks.bicep' = {
  name: 'aks'
  scope: rg
  params: {    
    location: resourceLocation
    tags: tags
    aksAdminGroupObjectIds: aksAdminGroupObjectIds
    aksName: aksName
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

// Creation of the UAMI and Federated Identity Credentials
// These modules creates the UAMIs and the Federated Identity Credentials

// Retrieves the names of the UAMIs from the federationConfigs parameter
var uamiNames = [for config in federationConfigs: config.uamiTargetName]

module uami 'common-modules/uami.bicep' = {
  name: 'uami'
  scope: rg
  params: {
    uamiLocation: resourceLocation
    uamiNames: uamiNames
    tags: tags
  }
}

module federation 'aks-modules/federation.bicep' = [for config in federationConfigs: {
  name: 'fed-${take(uniqueString(config.uamiTargetName, config.k8sServiceAccountName), 13)}'
  scope: rg
  params: {
    parentUserAssignedIdentityName: config.uamiTargetName
    serviceAccountName: config.k8sServiceAccountName
    serviceAccountNamespace: config.k8sNamespace
    oidcIssuerUrl: aks.outputs.oidcIssuerUrl
  }
}]

// Role Assignmeents for RBAC

module rbac 'aks-modules/rbac.bicep' = {
  name: 'rbac'
  scope: rg
  params: {
    keyVaultId: akv.outputs.keyvaultId
    acrId: acr.outputs.acrId
    uamiIds: uami.outputs.uamiPrincipalIds 
    aksId: aks.outputs.aksId
    appGwId: appGw.outputs.appGwId
    vnetId: network.outputs.vnetId
  }
}

// Create APP GATEWAY

@description('Name of the Application Gateway')
param appGwName string = 'appgw-securesharer-mvp'

@description('Application Gateway SKU')
@allowed([
  'Standard_v2'
  'WAF_v2'
])
param appGwsku string ='WAF_v2'


@description('Public IP address name for the Application Gateway')
param appGwPublicIpName string = 'appgw-public-ip'



// Creates AppGW. Assumes subnet for appGW is in place [1] on array.
module appGw 'aks-modules/appgw.bicep' = {
  name: 'appgw'
  scope: rg
  params: {
    appGwName: appGwName
    location: resourceLocation
    tags: tags
    sku: appGwsku
    publicIpName: appGwPublicIpName
    appGwSubnetId: network.outputs.subnetIds[1]
  }
}

// Final outputs for main.bicep

output acrLoginServer string = acr.outputs.acrLoginServer
output acrName string = acr.outputs.acrName  
output aksName string = aks.outputs.aksName
output backendK8sServiceAccountName string = federationConfigs[0].k8sServiceAccountName
output databaseInitK8sServiceAccountName string = federationConfigs[1].k8sServiceAccountName
output resourceGroupName string = rg.name
output keyvaultName string = akv.outputs.keyvaultName
output appGwPublicIp string = appGw.outputs.publicIpAddress
output backendUamiClientId string = uami.outputs.uamiClientIds[0] 
output dbInitUamiClientId string = uami.outputs.uamiClientIds[1]  // DB Init UAMI
output tenantId string = tenantId
