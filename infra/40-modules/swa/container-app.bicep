// Deploys a minimal ACA app that just proves the plumbing works
@description('Container App name')
param containerAppName string

@description('Managed Environment ID')
param environmentId string

@description('Image to run (tag)')
param image string

@description('ACR login server (for the registries block)')
param acrLoginServer string

@description('Location')
param location string

@description('Common tags')
param tags object

resource app 'Microsoft.App/containerApps@2025-01-01' = {
  name: containerAppName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  tags: tags
  properties: {
    managedEnvironmentId: environmentId
    configuration: {
      registries: [
        {
          server: acrLoginServer
          identity: 'system'  // Use system-assigned identity for ACR access
        }
      ]
      ingress: {
        external: false  // Internal access only (for SWA backend linking)
        targetPort: 80
        transport: 'http'
        allowInsecure: true  // Since it's internal traffic from SWA
      }
      activeRevisionsMode: 'Single'
    }
    template: {
      containers: [
        {
          name: 'web'
          image: image      // e.g. “acrLoginServer/hello-world:latest”
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
}

output containerAppId string = app.id
output containerAppPrincipalId string = app.identity.principalId  // System identity principal ID for RBAC
