// Parameters for shared infrastructure deployment

@description('Location for the resources')
param resourceLocation string = 'spaincentral'


@description('Tags for the resources')
param tags object = {
  environment: 'dev'
  project: 'secure-secret-sharer'
  owner: 'Tiago'
}

@description('Azure Container Registry name')
param acrName string

@description('SKU for the ACR')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param acrSku string = 'Premium'

@description('Enable admin user for the ACR')
param acrEnableAdminUser bool = false

@description('Name of the Cosmos DB account')
param cosmosDbAccountName string = 'cosmos-sharer-shared'

@description('The name of the database to create')
param cosmosDatabaseName string = 'SecureSharer'

@description('The names of the containers to create')
param cosmosContainerNames array = ['secrets']


module acr 'shared-infra-modules/acr.bicep' = {
  name: 'acr'
  params: {
    tags: tags
    acrName: acrName
    location: resourceLocation
    sku: acrSku
    enableAdminUser: acrEnableAdminUser
  }
}

// Deploy Cosmos DB for shared use across K8S and SWA deployments
module cosmosDb 'shared-infra-modules/cosmos-db.bicep' = {
  name: 'deploy-cosmos-db'
  params: {
    cosmosDbAccountName: cosmosDbAccountName
    location: resourceLocation
    databaseName: cosmosDatabaseName
    containerNames: cosmosContainerNames
    tags: tags
    defaultTtl: 86400 // 24 hours TTL
  }
}

// =====================
// Outputs
// =====================

output acrName string = acr.outputs.acrName
output acrLoginServer string = acr.outputs.acrLoginServer
output cosmosDbEndpoint string = cosmosDb.outputs.cosmosDbEndpoint
output cosmosDbAccountName string = cosmosDb.outputs.cosmosDbAccountName
output cosmosDatabaseName string = cosmosDb.outputs.databaseName
output cosmosContainerNames array = cosmosDb.outputs.containerNames
