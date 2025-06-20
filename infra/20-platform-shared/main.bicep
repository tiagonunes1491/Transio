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

@description('The names of the databases to create')
param cosmosDatabaseNames array = [ 'swa-dev', 'swa-prod', 'k8s-dev', 'k8s-prod' ]

@description('The name of the container to create in each database')
param cosmosContainerName string = 'secret'

@description('Enable free tier for Cosmos DB (not supported on internal subscriptions)')
param cosmosEnableFreeTier bool = false

@description('Throughput for the container (minimum 1000 RU/s for autoscale)')
param cosmosThroughput int = 1000

// =====================
// Naming and Tagging Modules
// =====================

// Generate standardized tags using the tagging module
module standardTagsModule '../40-modules/core/tagging.bicep' = {
  name: 'standard-tags-platform'
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
  params: {
    projectCode: projectCode
    environment: environment
    serviceCode: serviceCode
    resourceType: 'cosmos'
  }
}

module acr '../40-modules/shared-services/acr.bicep' = {
  name: 'acr'
  params: {
    tags: standardTagsModule.outputs.tags
    acrName: acrNamingModule.outputs.resourceName
    location: resourceLocation
    sku: acrSku
    enableAdminUser: acrEnableAdminUser
  }
}

// Deploy Cosmos DB for shared use across K8S and SWA deployments
module cosmosDb '../40-modules/shared-services/cosmos-db.bicep' = {
  name: 'deploy-cosmos-db'
  params: {
    cosmosDbAccountName: cosmosNamingModule.outputs.resourceName
    location: resourceLocation
    databaseNames: cosmosDatabaseNames
    containerName: cosmosContainerName
    tags: standardTagsModule.outputs.tags
    defaultTtl: 86400 // 24 hours TTL
    enableFreeTier: cosmosEnableFreeTier // Disable free tier for internal subscriptions
    throughput: cosmosThroughput // Set valid autoscale throughput
  }
}

// =====================
// Outputs
// =====================

output acrName string = acr.outputs.acrName
output acrLoginServer string = acr.outputs.acrLoginServer
output cosmosDbEndpoint string = cosmosDb.outputs.cosmosDbEndpoint
output cosmosDbAccountName string = cosmosDb.outputs.cosmosDbAccountName
output cosmosDatabaseNames array = cosmosDb.outputs.databaseNames
output cosmosContainerName string = cosmosDb.outputs.containerName
