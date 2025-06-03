@description('The name of the static web app.')
param staticWebAppName string
@description('The location of the static web app.')
param location string = resourceGroup().location
@description('SKU for the static web app.')
param sku string = 'Standard'
@description('Tag for the static web app')
param tag object = {}
@description('Repository URL for the static web app')
param repositoryUrl string = ''
@description('Branch name for deployment')
param branch string = 'main'
@description('Backend API resource ID to link')
param backendApiResourceId string = ''

module staticWebApp 'swa-aca-modules/static-web-app.bicep' = {
  name: 'staticWebApp'
  params: {
    staticWebAppName: staticWebAppName
    location: location
    sku: sku
    tag: tag
    repositoryUrl: repositoryUrl
    branch: branch
    backendApiResourceId: backendApiResourceId
  }
}

output staticWebAppUrl string = staticWebApp.outputs.staticWebAppUrl
output staticWebAppId string = staticWebApp.outputs.staticWebAppId
output staticWebAppName string = staticWebApp.outputs.staticWebAppName
output defaultHostname string = staticWebApp.outputs.defaultHostname
