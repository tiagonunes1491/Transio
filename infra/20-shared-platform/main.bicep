// Shared Platform Infrastructure for Secure Secret Sharer
// Deploys shared platform resources including ACR and Cosmos DB

// Resource configuration
@description('Location for the resources')
param resourceLocation string = 'spaincentral'

@description('Environment for deployment')
@allowed(['dev', 'prod', 'shared'])
param environment string = 'shared'

@description('Project code')
param projectCode string = 'ss'

@description('Service code for shared platform')
param serviceCode string = 'plat'

// Tagging configuration
@description('Cost center for billing')
param costCenter string = '1000'

@description('Created by information')
param createdBy string = 'bicep-deployment'

@description('Owner')
param owner string = 'tiago-nunes'

@description('Owner email')
param ownerEmail string = 'tiago.nunes@example.com'

@description('Creation date for tagging')
param createdDate string = utcNow('yyyy-MM-dd')

@description('SKU for the ACR')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param acrSku string = 'Premium'

@description('Enable admin user for the ACR')
param acrEnableAdminUser bool = false

@description('The databases to create with their containers')
param cosmosDbConfig array = [
  {
    name: 'swa-dev'
    containers: [
      {
        name: 'secret'
        partitionKey: { paths: ['/link_id'], kind: 'Hash' }
        defaultTtl: 86400
        autoscaleSettings: { maxThroughput: 1000 }
      }
    ]
  }
  {
    name: 'swa-prod'
    containers: [
      {
        name: 'secret'
        partitionKey: { paths: ['/link_id'], kind: 'Hash' }
        defaultTtl: 86400
        autoscaleSettings: { maxThroughput: 1000 }
      }
    ]
  }
  {
    name: 'aks-dev'
    containers: [
      {
        name: 'secret'
        partitionKey: { paths: ['/link_id'], kind: 'Hash' }
        defaultTtl: 86400
        autoscaleSettings: { maxThroughput: 1000 }
      }
    ]
  }
  {
    name: 'aks-prod'
    containers: [
      {
        name: 'secret'
        partitionKey: { paths: ['/link_id'], kind: 'Hash' }
        defaultTtl: 86400
        autoscaleSettings: { maxThroughput: 1000 }
      }
    ]
  }
]

@description('Enable free tier for Cosmos DB (not supported on internal subscriptions)')
param cosmosEnableFreeTier bool = false

// =====================
// Naming and Tagging Modules
// =====================

// Generate standardized tags using the tagging module
module standardTagsModule '../40-modules/core/tagging.bicep' = {
  name: 'standard-tags-platform'
  scope: subscription()
  params: {
    environment: environment
    project: projectCode
    service: serviceCode
    costCenter: costCenter
    createdBy: createdBy
    owner: owner
    ownerEmail: ownerEmail
    createdDate: createdDate
  }
}

// Generate ACR name using naming module
module acrNamingModule '../40-modules/core/naming.bicep' = {
  name: 'acr-naming'
  scope: subscription()
  params: {
    projectCode: projectCode
    environment: environment
    serviceCode: serviceCode
    resourceType: 'acr'
  }
}

// Generate Cosmos DB name using naming module
module cosmosNamingModule '../40-modules/core/naming.bicep' = {
  name: 'cosmos-naming'
  scope: subscription()
  params: {
    projectCode: projectCode
    environment: environment
    serviceCode: serviceCode
    resourceType: 'cosmos'
  }
}

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

// Deploy Cosmos DB for shared use across AKS and SWA deployments
module cosmosDb '../40-modules/core/cosmos-db.bicep' = {
  name: 'deploy-cosmos-db'
  params: {
    cosmosDbAccountName: cosmosNamingModule.outputs.resourceName
    location: resourceLocation
    databases: cosmosDbConfig
    tags: standardTagsModule.outputs.tags
    enableFreeTier: cosmosEnableFreeTier // Disable free tier for internal subscriptions
  }
}

// =====================
// Outputs
// =====================

output acrName string = acr.outputs.acrName
output acrLoginServer string = acr.outputs.acrLoginServer
output cosmosDbEndpoint string = cosmosDb.outputs.cosmosDbEndpoint
output cosmosDbAccountName string = cosmosDb.outputs.cosmosDbAccountName
output cosmosDbDatabases array = cosmosDb.outputs.databases
