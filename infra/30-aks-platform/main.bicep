/*
 * =============================================================================
 * AKS Platform Infrastructure for Secure Secret Sharer
 * =============================================================================
 * 
 * This Bicep template deploys the complete Azure Kubernetes Service (AKS) platform
 * infrastructure for the Secure Secret Sharer application. It establishes a
 * production-ready Kubernetes environment with comprehensive security, networking,
 * and application gateway capabilities for hosting containerized workloads.
 * 
 * ARCHITECTURE OVERVIEW:
 * ┌─────────────────────────────────────────────────────────────────────────┐
 * │                         AKS Platform Infrastructure                     │
 * ├─────────────────────────────────────────────────────────────────────────┤
 * │  Networking Layer           │  Security Layer                           │
 * │  ┌─────────────────────┐   │  ┌─────────────────────────────────────┐  │
 * │  │ Virtual Network     │   │  │ Azure Key Vault                     │  │
 * │  │ • AKS Subnet        │───┼──│ • Secrets Management                │  │
 * │  │ • AppGW Subnet      │   │  │ • Certificate Storage               │  │
 * │  │ • Network Security  │   │  │ • RBAC Integration                  │  │
 * │  │   Groups            │   │  │                                     │  │
 * │  └─────────────────────┘   │  │ Managed Identities                  │  │
 * │                             │  │ • Workload Identity                 │  │
 * │  Application Gateway        │  │ • Federated Credentials             │  │
 * │  ┌─────────────────────┐   │  │ • Service Account Binding           │  │
 * │  │ WAF_v2 SKU          │   │  └─────────────────────────────────────┘  │
 * │  │ SSL Termination     │   │                                          │
 * │  │ Load Balancing      │───┼──┐ AKS Cluster                           │
 * │  │ AGIC Integration    │   │  │ ┌─────────────────────────────────┐  │
 * │  └─────────────────────┘   │  │ │ System Node Pool               │  │
 * │                             │  │ │ User Node Pool                 │  │
 * └─────────────────────────────┘  │ │ OIDC Issuer                    │  │
 *                                  │ │ Azure CNI Networking           │  │
 *                                  │ │ Container Registry Integration │  │
 *                                  │ │ Cosmos DB Connectivity         │  │
 *                                  │ └─────────────────────────────────┘  │
 *                                  └─────────────────────────────────────┘
 * 
 * KEY FEATURES:
 * • Production-Ready AKS: Multi-node pool cluster with auto-scaling capabilities
 * • Application Gateway: WAF-enabled ingress with SSL termination and load balancing
 * • Comprehensive Security: Key Vault integration, managed identities, and RBAC
 * • Network Isolation: Dedicated VNet with subnet segmentation and NSG protection
 * • Workload Identity: Federated authentication for Kubernetes service accounts
 * • Platform Integration: Seamless connectivity to shared ACR and Cosmos DB services
 * • Infrastructure as Code: Complete automation with standardized naming and tagging
 * 
 * SECURITY CONSIDERATIONS:
 * • Network segmentation with dedicated subnets for AKS and Application Gateway
 * • Web Application Firewall (WAF) protection for ingress traffic
 * • Azure Key Vault integration for secrets and certificate management
 * • Managed identities for secure service-to-service authentication
 * • RBAC-enabled Key Vault with granular access controls
 * • Federated identity credentials for GitHub Actions integration
 * • Container image security through shared Azure Container Registry
 * • Network Security Groups with least privilege access rules
 * 
 * DEPLOYMENT SCOPE:
 * This template operates at subscription scope and deploys comprehensive
 * AKS platform infrastructure within the resource group created by the
 * corresponding AKS landing zone template.
 */
targetScope = 'subscription'

/*
 * =============================================================================
 * PARAMETER DEFINITIONS
 * =============================================================================
 * 
 * These parameters configure the AKS platform deployment, establishing
 * cluster specifications, networking configurations, security settings,
 * and integration points with shared platform services.
 */

/*
 * INFRASTRUCTURE CONFIGURATION PARAMETERS
 * Core settings that define the deployment environment and resource targeting
 */
@description('Azure Active Directory tenant ID for Key Vault authentication and RBAC configuration')
param tenantId string = subscription().tenantId

@description('Azure region where AKS platform resources will be deployed')
param resourceLocation string = 'spaincentral'

@description('Target resource group name for AKS platform deployment - created by landing zone')
param rgName string = 'rg-ssharer-k8s-spoke-dev'

/*
 * ORGANIZATIONAL NAMING PARAMETERS
 * These parameters establish the naming hierarchy for all resources:
 * Pattern: {projectCode}-{environment}-{serviceCode}-{resourceType}
 */
@description('Project code - root identifier for the Secure Secret Sharer project')
param projectCode string = 'ss'

@description('Service code for AKS platform - identifies Kubernetes infrastructure components')
param serviceCode string = 'aks'

@description('Environment name for deployment targeting and resource isolation')
@allowed(['dev', 'prod'])
param environmentName string = 'dev'

/*
 * GOVERNANCE AND COMPLIANCE PARAMETERS
 * Essential metadata for resource governance, cost management, and audit compliance
 */
@description('Cost center for billing allocation and financial tracking')
param costCenter string = '1000'

@description('Deployment method identifier - tracks infrastructure provisioning source')
param createdBy string = 'bicep-deployment'

@description('Primary resource owner - accountable person for these infrastructure components')
param owner string = 'tiago-nunes'

@description('Owner contact email - primary point of contact for operational issues')
param ownerEmail string = 'tiago.nunes@example.com'

/*
 * SHARED INFRASTRUCTURE INTEGRATION PARAMETERS
 * Configuration for connecting to shared platform services deployed separately
 */
@description('Shared Cosmos DB account name from the shared platform infrastructure')
param cosmosDbAccountName string

@description('Cosmos DB database name for application data storage')
param cosmosDatabaseName string = 'SecureSharer'

@description('Cosmos DB container name for secrets storage')
param cosmosContainerName string = 'secrets'

@description('Shared infrastructure resource group name where Cosmos DB and ACR are deployed')
param sharedResourceGroupName string = 'rg-ssharer-artifacts-hub'

@description('Shared Azure Container Registry name from the shared platform infrastructure')
param acrName string

// Construct the Cosmos DB account ID from the shared resource group and account name
var cosmosDbAccountId = '/subscriptions/${subscription().subscriptionId}/resourceGroups/${sharedResourceGroupName}/providers/Microsoft.DocumentDB/databaseAccounts/${cosmosDbAccountName}'

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

// =====================
// Naming and Tagging Modules
// =====================

// Generate standardized tags using the tagging module
module standardTagsModule '../40-modules/core/tagging.bicep' = {
  name: 'standard-tags-aks-platform'
  scope: subscription()
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
  name: 'vnet-naming'
  scope: subscription()
  params: {
    projectCode: projectCode
    environment: environmentName
    serviceCode: serviceCode
    resourceType: 'vnet'
  }
}

module akvNamingModule '../40-modules/core/naming.bicep' = {
  name: 'akv-naming'
  scope: subscription()
  params: {
    projectCode: projectCode
    environment: environmentName
    serviceCode: serviceCode
    resourceType: 'kv'
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

// NSG
module appGwNsg '../40-modules/aks/nsg.bicep' = {
  name: 'appGwNsg'
  scope: rg
  params: {
    nsgName: appGwNsgNamingModule.outputs.resourceName
    tags: standardTagsModule.outputs.tags
    allowRules: appGwNsgAllowRules
    denyRules: appGwNsgDenyRules
    location: resourceLocation
  }
}

// Deployment for VNET 
// ! Order of subnets are important and should not be changed.
// The first subnet is for the AKS cluster and the second one is for the Application Gateway.

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

module network '../40-modules/core/network.bicep' = {
  name: 'network'
  scope: rg
  params: {
    vnetName: vnetNamingModule.outputs.resourceName
    location: resourceLocation
    addressSpace: addressSpace
    subnets: [
      for subnet in subnets: {
        name: subnet.name
        addressPrefix: subnet.addressPrefix
        networkSecurityGroupId: subnet.name == 'snet-agw'  ? appGwNsg.outputs.nsgId : null
      }
    ]  }
}

// Reference existing ACR from shared infrastructure
resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: acrName
  scope: resourceGroup(sharedResourceGroupName)
}

// Deployment for AKV

@minLength(3)
@maxLength(24)
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

module akv '../40-modules/core/keyvault.bicep' = {
  name: 'keyvault'
  scope: rg
  params: {
    keyvaultName: akvNamingModule.outputs.resourceName
    location: resourceLocation
    tags: standardTagsModule.outputs.tags
    sku: akvSku
    tenantId: tenantId
    enableRbac: akvRbac
    enablePurgeProtection: akvPurgeProtection
    secretsToSet: akvSecrets
  }
}

// Deployment for AKS

@description('DNS prefix for the AKS cluster')
param dnsPrefix string = uniqueString(rgName, 'aks')

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

module aks '../40-modules/aks/aks.bicep' = {
  name: 'aks'
  scope: rg
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

// Creation of the UAMI and Federated Identity Credentials
// These modules creates the UAMIs and the Federated Identity Credentials

// Retrieves the names of the UAMIs from the federationConfigs parameter
var uamiNames = [for config in federationConfigs: config.uamiTargetName]

module uami '../40-modules/core/uami.bicep' = {
  name: 'uami'
  scope: rg
  params: {
    uamiLocation: resourceLocation
    uamiNames: uamiNames
    tags: standardTagsModule.outputs.tags
  }
}

module federation '../40-modules/aks/federation.bicep' = [for config in federationConfigs: {
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

module rbac '../40-modules/aks/rbac.bicep' = {
  name: 'rbac'
  scope: rg
  params: {
    keyVaultId: akv.outputs.keyvaultId
    acrId: acr.id
    uamiIds: uami.outputs.uamiPrincipalIds 
    aksId: aks.outputs.aksId
    appGwId: appGw.outputs.appGwId
    vnetId: network.outputs.vnetId
    cosmosDbAccountId: cosmosDbAccountId
  }
}

// Generate Public IP name for Application Gateway
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

// Create APP GATEWAY

@description('Application Gateway SKU')
@allowed([
  'Standard_v2'
  'WAF_v2'
])
param appGwSku string = 'WAF_v2'

// Creates AppGW. Assumes subnet for appGW is in place [1] on array.
module appGw '../40-modules/aks/appgw.bicep' = {
  name: 'appgw'
  scope: rg
  params: {
    appGwName: appGwNamingModule.outputs.resourceName
    location: resourceLocation
    tags: standardTagsModule.outputs.tags
    sku: appGwSku
    publicIpName: appGwPipNamingModule.outputs.resourceName
    appGwSubnetId: network.outputs.subnetIds[1]
  }
}

// Final outputs for main.bicep

output acrLoginServer string = acr.properties.loginServer
output acrName string = acr.name
output aksName string = aks.outputs.aksName
output backendK8sServiceAccountName string = federationConfigs[0].k8sServiceAccountName
output databaseInitK8sServiceAccountName string = federationConfigs[1].k8sServiceAccountName
output resourceGroupName string = rg.name
output keyvaultName string = akv.outputs.keyvaultName
output appGwPublicIp string = appGw.outputs.publicIpAddress
output backendUamiClientId string = uami.outputs.uamiClientIds[0] 
output dbInitUamiClientId string = uami.outputs.uamiClientIds[1]  // DB Init UAMI
output tenantId string = tenantId
output cosmosDbAccountName string = cosmosDbAccountName
output cosmosDatabaseName string = cosmosDatabaseName
output cosmosContainerName string = cosmosContainerName
