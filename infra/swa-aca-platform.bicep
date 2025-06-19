// Common parameteers for the secure secret sharer application using Static Web Apps and Azure Container Apps
// Creation of the resource group 

targetScope = 'subscription'

@description('The Azure AD tenant ID that should be used for authenticating requests to the key vault. Defaults to the current subscription tenant ID.')
param tenantId string = subscription().tenantId

@description('Location for the resources')
param resourceLocation string = 'spaincentral'

@description('Name of the resource group')
param rgName string = 'rg-secure-sharer-swa-aca-dev'

@description('Tags for the resources')
param tags object = {
  environment: 'dev'
  project: 'secure-secret-sharer'
  owner: 'Tiago'
  flavor: 'SWA-ACA'
}

resource rg 'Microsoft.Resources/resourceGroups@2025-03-01' = {
  name: rgName
  location: resourceLocation
  tags: tags
}

// Deployment for VNET 
// ! Order of subnets are important and should not be changed.
// The first subnet is for the ACA, the second one is for the PaaS DB, the third is for Private Endpoints, the fourth is for deployment scripts.

@description('Name of the virtual network')
param vnetName string = 'vnet-secureSecretSharer'

@description('Address space for the virtual network')
var addressSpace  = [
  '10.0.0.0/16'
]

@description('Subnets for the virtual network')
var subnets  = [
  {
    name: 'snet-aca'
    addressPrefix: '10.0.10.0/23'
  }
  {
    name: 'snet-db'
    addressPrefix: '10.0.20.0/24'
    delegations: [
      {
        name: 'dbDelegation'
        properties: {
          serviceName: 'Microsoft.DBforPostgreSQL/flexibleServers'
        }
      }
    ]
  }
  {
    name: 'snet-pe'
    addressPrefix: '10.0.30.0/24'
    privateEndpointNetworkPolicies: 'Disabled'
  }
  {
    name: 'snet-aci'
    addressPrefix: '10.0.40.0/24'
    serviceEndpoints: [
      {
        service: 'Microsoft.Storage'
      }
    ]
    delegations: [
      {
        name: 'aciDelegation'
        properties: {
          serviceName: 'Microsoft.ContainerInstance/containerGroups'
        }
      }
    ]
  }
]


module network 'common-modules/network.bicep' = {
  name: 'network'
  scope: rg
  params: {
    vnetName: vnetName
    location: resourceLocation
    addressSpace: addressSpace
    subnets: subnets
  }
}

// Deployment for the Azure Key Vault

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

// Deployment of the Private DNS Zone for the Key Vault

module deployKVDNSZone 'common-modules/private-dns-zone.bicep' = {
  name: 'KeyVaultPrivateDnsZone'
  scope: rg
  params: {
    privateDnsZoneName: 'privatelink.vaultcore.azure.net'
    vnetId: network.outputs.vnetId
    privateDnsZoneTags:tags
    }
}

// Depoyment of the Private Endpoint for the Key Vault

module akvPE 'common-modules/private-endpoint.bicep' = {
  name: 'akvPE'
  scope: rg
  params: {
    privateEndpointName: 'pe-${akv.outputs.keyvaultName}'
    privateEndpointLocation: resourceLocation
    privateEndpointSubnetId: network.outputs.subnetIds[2] // The third subnet is for Private Endpoints
    privateEndpointGroupId: 'vault'
    privateEndpointServiceId: akv.outputs.keyvaultId
    privateEndpointTags: tags
    privateDnsZoneIds: [deployKVDNSZone.outputs.privateDnsZoneId] 
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

module acr 'common-modules/acr.bicep' = {
  name: 'acr'
  scope: rg
  params: {
    acrName: acrName
    location: resourceLocation
    sku: acrSku
    enableAdminUser: acrEnableAdminUser
  }
}

// Create DNS Zone for Azure Container Registry Private Endpoint
module deployACRDNSZone 'common-modules/private-dns-zone.bicep' = {
  name: 'ACRPrivateDnsZone'
  scope: rg
  params: {
    privateDnsZoneName: 'privatelink.azurecr.io'
    vnetId: network.outputs.vnetId
    privateDnsZoneTags: tags
  }
}


// Depoyment of the Private Endpoint for the Azure Container Registry

module acrPE 'common-modules/private-endpoint.bicep' = {
  name: 'acrPE'
  scope: rg
  params: {
    privateEndpointName: 'pe-${acr.outputs.acrName}'
    privateEndpointLocation: resourceLocation
    privateEndpointSubnetId: network.outputs.subnetIds[2] // The third subnet is for Private Endpoints
    privateEndpointGroupId: 'registry'
    privateEndpointServiceId: acr.outputs.acrId
    privateEndpointTags: tags
    privateDnsZoneIds: [
      deployACRDNSZone.outputs.privateDnsZoneId 
    ] 
  }
}

// Create Workspace to receive logs

@description('Name of the workspace')
param workspaceName string = 'ws-sec-sharer'

module workspace 'common-modules/workspace.bicep' = {
  name: 'workspace'
  scope: rg
  params: {
    workspaceName: workspaceName
    location: resourceLocation
    tags: tags
  }
}

// Create Cosmos DB account and database

param cosmosDbAccountName string = 'cosmos-sharer-aca-dev'

module cosmosDb 'swa-aca-modules/cosmos-db.bicep' = {
  name: 'cosmosDb'
  scope: rg
  params: {
    cosmosDbAccountName: cosmosDbAccountName
    location: resourceLocation
    databaseName: 'SecureSharer'
    containerName: 'secrets'
    tags: tags
    throughput: 400 // Minimum for shared throughput
    defaultTtl: 86400 // 24 hours TTL
  }
}

// Deploying Azure Container Apps

@description('Name of the Azure Container Apps Environment')
param acaEnvName string = 'cae-sharer-aca-dev' 

module acaEnvironment 'swa-aca-modules/aca-environment.bicep' = {
  name: 'acaEnvironment'
  scope: rg
  params: {
    acaEnvironmentName: acaEnvName
    acaEnvironmentLocation: resourceLocation
    acaEnvironmentTags: tags
    workspaceId: workspace.outputs.workspaceId
    acaEnvironmentSubnetId: network.outputs.subnetIds[0] // The first subnet is for the ACA
  }
}

// Create a UAMI for the Azure Container App
@description('Name of the System Assigned Managed Identity for the Azure Container App')
param acaUamiName array = [
  'aca-sharer-identity'
]

module uami 'common-modules/uami.bicep' = {
  name: 'uami'
  scope: rg
  params: {
    uamiLocation: resourceLocation
    uamiNames: acaUamiName
    tags: tags
  }
}

// Create a storage account for deployment scripts
@description('Name of the storage account for deployment scripts')
param storageAccountName string = 'sadeploysharerdev'

module deploymentStorageAccount 'common-modules/storage.bicep' = {
  name: 'deploymentStorageAccount'
  scope: rg
  params: {
    storageAccountName: storageAccountName
    location: resourceLocation
    tags: tags
    sku: 'Standard_LRS'
    kind: 'StorageV2'
    vnetId: network.outputs.vnetId
    acaSubnetId: network.outputs.subnetIds[3] // The fourth subnet is for deployment scripts
  }
}




// Role Assignments for Key Vault and ACR access
module rbac 'swa-aca-modules/rbac.bicep' = {
  name: 'rbac'
  scope: rg
  params: {    keyVaultId: akv.outputs.keyvaultId
    acrId: acr.outputs.acrId
    uamiId: uami.outputs.uamiPrincipalIds[0] // Use the first UAMI principal ID
    acaSubnetId: network.outputs.subnetIds[3] // The fourth subnet is for deployment scripts (snet-aci)
    storageAccountId: deploymentStorageAccount.outputs.storageAccountId
  }
}

output acaEnvironmentId string = acaEnvironment.outputs.acaEnvironmentId
output acrLoginServer string = acr.outputs.acrLoginServer
output uamiId string = uami.outputs.uamiIds[0]
output keyVaultUri string = akv.outputs.keyvaultUri
output cosmosDbEndpoint string = cosmosDb.outputs.cosmosDbEndpoint
output cosmosDbAccountName string = cosmosDb.outputs.cosmosDbAccountName
output cosmosDbDatabaseName string = cosmosDb.outputs.databaseName
output cosmosDbContainerName string = cosmosDb.outputs.containerName

//Trigger change on main folder.
