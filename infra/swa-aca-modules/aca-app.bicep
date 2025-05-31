@description('Application name for the Azure Container App')
param appName string
@description('Location for the Azure Container App')
param appLocation string = resourceGroup().location
@description('The Azure Container Apps Environment ID for the app.')
param environmentId string
@description('The container image for the Azure Container App.')
param containerImage string
@description('Minimum number of replicas for the Azure Container App.')
param minReplicas int = 0
@description('Maximum number of replicas for the Azure Container App.')
param maxReplicas int = 1
@description('Target port for the Azure Container App.')
param targetPort int = 5000
@description('External Ingress for the Azure Container App.')
param externalIngress bool = true
@description('Secrets from Key Vault to be used in the Azure Container App.')
param secrets array = []
@description('Secret references as environment variables.')
param secretEnvironmentVariables array = []
@description('Environment variables for the Azure Container App.')
param environmentVariables array = []
@description('Tags for the Azure Container App.')
param appTags object = {}
@description('CPU limit for the Azure Container App in millicores (250 = 0.25 cores)')
param cpuLimit int = 250
@description('Memory limit for the Azure Container App in GB')
param memoryLimit string = '1Gi'


resource acaApp 'Microsoft.App/containerApps@2025-01-01' = {
  name: appName
  location: appLocation
  tags: appTags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    environmentId: environmentId
    configuration: {
      ingress: {
        external: externalIngress
        targetPort: targetPort
        transport: 'http'
      }
      secrets: [for secret in secrets: {
        name: secret.name
        keyVaultUrl: secret.keyVaultUri
        identity: 'system'
      }]
      activeRevisionsMode: 'Single'
    }
    template: {
      containers: [
        {
          name: appName
          image: containerImage
          resources: {
            cpu: cpuLimit
            memory: memoryLimit
          }
          env: union(secretEnvironmentVariables, environmentVariables)
        }
      ]
      scale: {
        minReplicas: minReplicas
        maxReplicas: maxReplicas
      }
    }
  }
}

//Outputs for the Azure Container App
output id string = acaApp.id
output name string = acaApp.name
output aFqdn string = acaApp.properties.configuration.ingress.fqdn
output samIPrincipalId string = acaApp.identity.principalId
