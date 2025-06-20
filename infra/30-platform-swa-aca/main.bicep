// infra/30-platform-swa-aca/main.bicep
// Single entry-point for platform: network, key vault, log analytics, PCA environment, UAMI, RBAC, plus ACA & SWA stubs

targetScope = 'resourceGroup'

@description('Azure AD tenant ID for Key Vault authentication')
param tenantId string = subscription().tenantId

@description('Deployment location')
param resourceLocation string = 'spaincentral'

@description('Project code')
param projectCode string = 'ss'

@description('Service code for SWA/ACA platform')
param serviceCode string = 'swa'

@description('Environment name')
@allowed(['dev', 'prod'])
param environmentName string = 'dev'

// Tagging configuration
@description('Cost center for billing')
param costCenter string = '1000'

@description('Created by information')
param createdBy string = 'bicep-deployment'

@description('Owner')
param owner string = 'tiago-nunes'

@description('Owner email')
param ownerEmail string = 'tiago.nunes@example.com'

@description('Image for the stub Container App')
param stubContainerImage string = '${acrLoginServer}/hello-world:latest'

// ========== SHARED INFRASTRUCTURE REFERENCES ==========
@description('Existing ACR name from shared infrastructure')
param acrName string

@description('Existing ACR login server from shared infrastructure')
param acrLoginServer string

@description('Existing ACR resource ID from shared infrastructure')
param acrId string

@description('Existing Cosmos DB endpoint from shared infrastructure')
param cosmosDbEndpoint string

@description('Cosmos database name to use (existing)')
param cosmosDatabaseName string = 'paas-dev'

@description('Cosmos container name to use (existing)')
param cosmosContainerName string = 'secret'

// ========== VNET & SUBNETS ==========
var addressSpace = [ '10.0.0.0/16' ]
var subnets = [
  {
    name:          'snet-aca'
    addressPrefix: '10.0.10.0/23'
  }
  {
    name:                             'snet-pe'
    addressPrefix:                    '10.0.30.0/24'
    privateEndpointNetworkPolicies:  'Disabled'
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
  name: 'vnet-naming'
  params: {
    projectCode: projectCode
    environment: environmentName
    serviceCode: serviceCode
    resourceType: 'vnet'
  }
}

module akvNamingModule '../40-modules/core/naming.bicep' = {
  name: 'akv-naming'
  params: {
    projectCode: projectCode
    environment: environmentName
    serviceCode: serviceCode
    resourceType: 'kv'
  }
}

module lawNamingModule '../40-modules/core/naming.bicep' = {
  name: 'law-naming'
  params: {
    projectCode: projectCode
    environment: environmentName
    serviceCode: serviceCode
    resourceType: 'law'
  }
}

module acaEnvNamingModule '../40-modules/core/naming.bicep' = {
  name: 'aca-env-naming'
  params: {
    projectCode: projectCode
    environment: environmentName
    serviceCode: serviceCode
    resourceType: 'cae'
  }
}

module uamiNamingModule '../40-modules/core/naming.bicep' = {
  name: 'uami-naming'
  params: {
    projectCode: projectCode
    environment: environmentName
    serviceCode: serviceCode
    resourceType: 'uai'
  }
}

module containerAppNamingModule '../40-modules/core/naming.bicep' = {
  name: 'container-app-naming'
  params: {
    projectCode: projectCode
    environment: environmentName
    serviceCode: serviceCode
    resourceType: 'ca'
  }
}

module swaNamingModule '../40-modules/core/naming.bicep' = {
  name: 'swa-naming'
  params: {
    projectCode: projectCode
    environment: environmentName
    serviceCode: serviceCode
    resourceType: 'swa'
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
    privateEndpointServiceId:  acrId
    privateEndpointTags:       standardTagsModule.outputs.tags
    privateDnsZoneIds:         [ acrDns.outputs.privateDnsZoneId ]
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

// ========== ACA ENVIRONMENT & UAMI ==========
module acaEnv '../40-modules/swa-aca/aca-environment.bicep' = {
  name:  'acaEnvironment'
  params: {
    acaEnvironmentName:     acaEnvNamingModule.outputs.resourceName
    acaEnvironmentLocation: resourceLocation
    acaEnvironmentTags:     standardTagsModule.outputs.tags
    workspaceId:            workspace.outputs.workspaceId
    acaEnvironmentSubnetId: network.outputs.subnetIds[0]
  }
}

module uami '../40-modules/core/uami.bicep' = {
  name: 'uami'
  params: {
    uamiNames:     [ uamiNamingModule.outputs.resourceName ]
    uamiLocation:  resourceLocation
    tags:          standardTagsModule.outputs.tags
  }
}

// ========== RBAC ASSIGNMENTS ==========
module rbac '../40-modules/swa-aca/rbac.bicep' = {
  name: 'rbac'
  params: {
    keyVaultId:    akv.outputs.keyvaultId
    acrId:         acrId
    uamiId:        uami.outputs.uamiPrincipalIds[0]
  }
}

// ========== STUB CONTAINER APP ==========
module stubApp '../40-modules/swa-aca/container-app.bicep' = {
  name:  'stubContainerApp'
  params: {
    containerAppName: containerAppNamingModule.outputs.resourceName
    environmentId:    acaEnv.outputs.acaEnvironmentId
    image:            stubContainerImage
    acrLoginServer:   acrLoginServer
    uamiId:           uami.outputs.uamiIds[0]
    location:         resourceLocation      // same as ACA env
    tags:             standardTagsModule.outputs.tags
  }
}

// ========== STATIC WEB APP STUB ==========
module staticWebApp '../40-modules/swa-aca/static-web-app.bicep' = {
  name:  'staticWebApp'
  params: {
    swaName:  swaNamingModule.outputs.resourceName
    location: 'westeurope'     // Static Web Apps aren’t supported in Spain Central (yet)
    uamiId:   uami.outputs.uamiIds[0]
    tags:     standardTagsModule.outputs.tags
  }
}


// ========== OUTPUTS ==========
output acrName               string = acrName
output acrLoginServer        string = acrLoginServer  // Using parameter instead of module output
output acaEnvironmentId      string = acaEnv.outputs.acaEnvironmentId
output uamiId                string = uami.outputs.uamiIds[0]
output keyVaultUri           string = akv.outputs.keyvaultUri
output cosmosDbEndpoint      string = cosmosDbEndpoint
output cosmosDatabaseName    string = cosmosDatabaseName
output cosmosContainerName   string = cosmosContainerName
output containerAppId        string = stubApp.outputs.containerAppId
output staticWebAppId        string = staticWebApp.outputs.staticWebAppId
