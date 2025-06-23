// infra/40-modules/swa/container-app.bicep
// Deploys Azure Container App - Unopinionated module

// ========== PARAMETERS ==========

@description('Application name for the Azure Container App')
param containerAppName string

@description('Location for the Azure Container App')
param location string = resourceGroup().location

@description('The Azure Container Apps Environment ID for the app.')
param environmentId string

@description('The container image for the Azure Container App.')
param image string

@description('Minimum number of replicas for the Azure Container App.')
param minReplicas int = 0

@description('Maximum number of replicas for the Azure Container App.')
param maxReplicas int = 1

@description('Enable ingress for the Azure Container App.')
param enableIngress bool = true

@description('Target port for the Azure Container App.')
param targetPort int = 80

@description('External Ingress for the Azure Container App.')
param externalIngress bool = false

@description('Ingress transport protocol (http, http2, auto)')
param ingressTransport string = 'auto'

@description('IP security restrictions for ingress')
param ipSecurityRestrictions array = []

@description('Secrets from Key Vault to be used in the Azure Container App.')
param secrets array = []

@description('Secret references as environment variables.')
param secretEnvironmentVariables array = []

@description('Environment variables for the Azure Container App.')
param environmentVariables array = []

@description('Tags for the Azure Container App.')
param tags object = {}

@description('CPU limit for the Azure Container App')
param cpuLimit string = '0.25'

@description('Memory limit for the Azure Container App')
param memoryLimit string = '0.5Gi'

@description('Managed identity configuration for the Azure Container App')
param identity object = {}

@description('Container registry configurations')
param registries array = []

@description('Active revisions mode (Single or Multiple)')
param activeRevisionsMode string = 'Single'

@description('Scaling rules for the Azure Container App')
param scalingRules array = []

@description('Volumes for the Azure Container App')
param volumes array = []

@description('Volume mounts for the container')
param volumeMounts array = []

@description('Additional containers to run in the same pod')
param additionalContainers array = []

// ========== CONTAINER APP ==========

resource app 'Microsoft.App/containerApps@2025-01-01' = {
  name: containerAppName
  location: location
  tags: tags
  identity: empty(identity) ? null : identity
  properties: {
    environmentId: environmentId
    configuration: {
      ingress: enableIngress ? {
        external: externalIngress
        targetPort: targetPort
        transport: ingressTransport
        ipSecurityRestrictions: ipSecurityRestrictions
      } : null
      secrets: [for secret in secrets: {        name: secret.name
        keyVaultUrl: secret.keyVaultUrl
        identity: secret.identity
      }]
      activeRevisionsMode: activeRevisionsMode
      registries: registries
    }
    template: {
      containers: concat([
        {
          name: containerAppName
          image: image
          resources: {
            cpu: json(cpuLimit)
            memory: memoryLimit
          }
          env: union(secretEnvironmentVariables, environmentVariables)
          volumeMounts: volumeMounts
        }
      ], additionalContainers)
      scale: union({
        minReplicas: minReplicas
        maxReplicas: maxReplicas
      }, empty(scalingRules) ? {} : { rules: scalingRules })
      volumes: volumes
    }
  }
}

// ========== OUTPUTS ==========
output containerAppId string = app.id
output fqdn string = enableIngress ? app.properties.configuration.ingress.fqdn : ''
