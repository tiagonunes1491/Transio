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
// The first subnet is for the ACA,  the second one is for the PaaS DB, the third is for Private Endpoints.

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
    addressPrefix: '10.0.1.0/24'
    delegations: [
      {
        name: 'acaDelegation'
        properties: {
          serviceName: 'Microsoft.App/environments'
        }
      }
    ]
  }
    {
    name: 'snet-db'
    addressPrefix: '10.0.2.0/24'
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
    addressPrefix: '10.0.3.0/24'
    privateEndpointNetworkPolicies: 'Disabled'
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


// Create PostgreSQL Flexible Server

// Define params for DB (values from .bicepparam)
param dbServerName string = 'pgs-sharer-aca-dev'
param dbAdminLogin string = 'pgadminuser'
@secure()
param dbAdminPassword string // This will come from your .bicepparam file or pipeline

module postgresqlServer 'swa-aca-modules//postgresql-flexible.bicep' = {
  name: 'postgresqlServer'
  scope: rg
  params: {
    serverName: dbServerName
    location: resourceLocation
    administratorLogin: dbAdminLogin
    administratorLoginPassword: dbAdminPassword
    skuName: 'Standard_B1ms' // Example SKU, adjust as needed
    skuTier: 'Burstable' // Example tier, adjust as needed
    postgresVersion: '15' // Example version, adjust as needed
    delegatedSubnetId: network.outputs.subnetIds[1] // The second subnet is for the PaaS DB
    databaseName: 'secureSecretSharerDB' // Initial database name
    tags: tags
    logAnalyticsWorkspaceId: workspace.outputs.workspaceId // Link to the Log Analytics workspace
  }
}


// Deploying Azure Container Apps

@description('Name of the Azure Container Apps Environment')
param acaEnvName string = 'cae-sharer-aca-dev' 
@description('Name of the container and tag to pull to ACA')
param containerImage string = 'secure-secret-sharer:latest' // This should match the image pushed to ACR
@description('CPU limit for the Azure Container App in millicores (250 = 0.25 cores)')
param acaCpuLimit int = 250 // 0.25 cores in millicores
@description('Memory limit for the Azure Container App in GB')
param acaMemoryLimit string = '1Gi' // 1 GB memory limit

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

var acaEnvironmentVariables = [
  {
    name: 'DATABASE_HOST'
    value: postgresqlServer.outputs.fullyQualifiedDomainName
  }
  {
    name: 'DATABASE_PORT'
    value: '5432'
  }
  {
    name: 'DATABASE_NAME'
    value: postgresqlServer.outputs.databaseName
  }
]

// Secret references - these will reference secrets stored in Key Vault
var acaSecretReferences = [for secretName in items(akvSecrets): {
  name: toUpper(replace(secretName.key, '-', '_'))
  secretRef: secretName.key
}]

module acaApp 'swa-aca-modules/aca-app.bicep' = {
  name: 'acaApp'
  scope: rg
  params: {
    appName: 'secure-secret-sharer-aca-dev'
    appLocation: resourceLocation
    environmentId: acaEnvironment.outputs.acaEnvironmentId
    containerImage: '${acr.outputs.acrLoginServer}/${containerImage}' 
    minReplicas: 0
    maxReplicas: 1
    targetPort: 5000
    externalIngress: true
    secrets: [for secretItem in items(akvSecrets): {
      name: secretItem.key
      identity: 'system'
      keyVaultUri: '${akv.outputs.keyvaultUri}secrets/${secretItem.key}'    }]
    environmentVariables: acaEnvironmentVariables
    secretEnvironmentVariables: acaSecretReferences
    appTags: tags
    cpuLimit: acaCpuLimit
    memoryLimit: acaMemoryLimit
  }
}

// Role Assignments for Key Vault and ACR access
module rbac 'swa-aca-modules/rbac.bicep' = {
  name: 'rbac'
  scope: rg
  params: {
    keyVaultId: akv.outputs.keyvaultId
    acrId: acr.outputs.acrId
    samiId: acaApp.outputs.samIPrincipalId 
  }
}
