// infra/40-modules/swa/container-app.bicep
// Deploys Azure Container App with Key Vault secrets integration

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

@description('Target port for the Azure Container App.')
param targetPort int = 80

@description('External Ingress for the Azure Container App.')
param externalIngress bool = false

@description('Secrets from Key Vault to be used in the Azure Container App.')
param secrets array = []

@description('Secret references as environment variables.')
param secretEnvironmentVariables array = []

@description('Environment variables for the Azure Container App.')
param environmentVariables array = []

@description('Tags for the Azure Container App.')
param tags object = {}

@description('CPU limit for the Azure Container App in millicores (0.25 = 250m)')
param cpuLimit string = '0.25'

@description('Memory limit for the Azure Container App in GB')
param memoryLimit string = '0.5Gi'

@description('User Assigned Managed Identity for the Azure Container App')
param userAssignedIdentityId string = ''

// ========== CONTAINER APP ==========

resource app 'Microsoft.App/containerApps@2025-01-01' = {
  name: containerAppName
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityId}': {}    }
  }
  properties: {
    environmentId: environmentId
    configuration: {
      ingress: {
        external: externalIngress
        targetPort: targetPort
        transport: 'http'
        ipSecurityRestrictions: [
          {
            name: 'AllowStaticWebApps'
            description: 'Allow traffic from Azure Static Web Apps'
            ipAddressRange: 'AzureStaticApps'
            action: 'Allow'
          }
        ]
      }
      secrets: [for secret in secrets: {
        name: secret.name
        keyVaultUrl: secret.keyVaultUri
        identity: userAssignedIdentityId
      }]
      activeRevisionsMode: 'Single'
      registries: [
        {
          server: split(image, '/')[0] // Extract ACR server from image
          identity: userAssignedIdentityId
        }
      ]
    }
    template: {
      containers: [        
      {
          name: containerAppName
          image: image
          resources: {
            cpu: json(cpuLimit) // Convert string to number for API
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

// ========== OUTPUTS ==========
output containerAppId string = app.id
output fqdn string = app.properties.configuration.ingress.fqdn
