// Deploys a minimal ACA app that just proves the plumbing works
@description('Container App name')
param containerAppName string

@description('Managed Environment ID')
param environmentId string

@description('Image to run (tag)')
param image string

@description('ACR login server (for the registries block)')
param acrLoginServer string

@description('User-assigned identity that already has AcrPull')
param uamiId string

@description('Location')
param location string

@description('Common tags')
param tags object

resource app 'Microsoft.App/containerApps@2025-02-02-preview' = {
  name: containerAppName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${uamiId}': {}
    }
  }
  tags: tags
  properties: {
    managedEnvironmentId: environmentId
    configuration: {
      registries: [
        {
          server: acrLoginServer
          identity: uamiId
        }
      ]
      ingress: {
        external: true
        targetPort: 80
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
