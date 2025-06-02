@description('The name of the static web app.')
param staticWebAppName string
@description('The location of the static web app.')
param location string = resourceGroup().location
@description('SKU for the static web app.')
param sku string = 'Standard'
@description('custom domain for the static web app')
param customDomain string = ''
@description('Tag for the static web app')
param tag object = {}
@description('Repository URL for the static web app')
param repositoryUrl string = ''
@description('Branch name for deployment')
param branch string = 'main'
@description('Backend API FQDN for the static web app')
param backendApiFqdn string = ''

module staticWebApp 'swa-aca-modules/static-web-app.bicep' = {
  name: 'staticWebApp'
  params: {
    staticWebAppName: staticWebAppName
    location: location
    sku: sku
    customDomain: customDomain
    tag: tag
    repositoryUrl: repositoryUrl
    branch: branch
    backendApiFqdn: backendApiFqdn
  }
}

output staticWebAppUrl string = staticWebApp.outputs.staticWebAppUrl
output staticWebAppId string = staticWebApp.outputs.staticWebAppId
output staticWebAppName string = staticWebApp.outputs.staticWebAppName
output customDomainId string = staticWebApp.outputs.customDomainId
output defaultHostname string = staticWebApp.outputs.defaultHostname
