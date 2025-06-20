// Parameters for shared infrastructure deployment

@description('Location for the resources')
param resourceLocation string = 'spaincentral'

@description('Environment for deployment')
@allowed(['dev', 'staging', 'prod', 'shared'])
param environment string = 'shared'

@description('Project code')
param projectCode string = 'ss'

@description('Service code for shared platform')
param serviceCode string = 'plat'

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
// Name Generation and Tagging
// =====================

// Environment mapping
var envMapping = {
  dev: 'd'
  staging: 's'
  prod: 'p'
  shared: 'sh'
}

// Standard tags
var standardTags = {
  environment: environment
  project: projectCode
  service: serviceCode
  costCenter: costCenter
  createdBy: createdBy
  owner: owner
  ownerEmail: ownerEmail
  createdDate: createdDate
  managedBy: 'bicep'
  deployment: deployment().name
}

// Generate resource names using naming convention
var acrName = replace('${projectCode}-${envMapping[environment]}-${serviceCode}-acr', '-', '') // ACR names can't contain dashes
var cosmosDbAccountName = replace('${projectCode}-${envMapping[environment]}-${serviceCode}-cosmos', '-', '') // Cosmos DB names can't contain dashes

module acr '../40-modules/shared-services/acr.bicep' = {
  name: 'acr'
  params: {
    tags: standardTags
    acrName: acrName
    location: resourceLocation
    sku: acrSku
    enableAdminUser: acrEnableAdminUser
  }
}

// Deploy Cosmos DB for shared use across K8S and SWA deployments
module cosmosDb '../40-modules/shared-services/cosmos-db.bicep' = {
  name: 'deploy-cosmos-db'
  params: {
    cosmosDbAccountName: cosmosDbAccountName
    location: resourceLocation
    databaseNames: cosmosDatabaseNames
    containerName: cosmosContainerName
    tags: standardTags
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
