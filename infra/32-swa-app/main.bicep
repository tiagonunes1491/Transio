// infra/32-swa-app/main.bicep
// Creates Container App and Static Web App using existing infrastructure

targetScope = 'resourceGroup'

@description('Deployment location')
param resourceLocation string = 'spaincentral'

@description('Project code')
param projectCode string = 'ss'

@description('Service code for SWA/ACA platform')
param serviceCode string = 'swa'

@description('Environment name')
@allowed(['dev', 'prod'])
param environmentName string = 'dev'

// Tagging configuration
@description('Cost center for billing')
param costCenter string = '1000'

@description('Created by information')
param createdBy string = 'bicep-deployment'

@description('Owner')
param owner string = 'tiago-nunes'

@description('Owner email')
param ownerEmail string = 'tiago.nunes@example.com'

// ========== EXISTING INFRASTRUCTURE REFERENCES ==========
@description('Container Apps Environment Resource Group Name')
param acaEnvironmentResourceGroupName string

@description('Container Apps Environment name')
param acaEnvironmentName string

@description('UAMI Resource Group Name')
param uamiResourceGroupName string

@description('UAMI name')
param uamiName string

@description('Container image for the application')
param containerImage string

@description('Secrets to retrieve from Key Vault')
param keyVaultSecrets array = []

@description('Environment variables for the Container App')
param environmentVariables array = []

@description('Secret environment variables for the Container App')
param secretEnvironmentVariables array = []

// Reference existing infrastructure
resource acaEnv 'Microsoft.App/managedEnvironments@2025-01-01' existing = {
  name: acaEnvironmentName
  scope: resourceGroup(subscription().subscriptionId, acaEnvironmentResourceGroupName)
}

resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: uamiName
  scope: resourceGroup(subscription().subscriptionId, uamiResourceGroupName)
}

// ========== NAMING AND TAGGING MODULES ==========

// Generate standardized tags using the tagging module
module standardTagsModule '../40-modules/core/tagging.bicep' = {
  scope: subscription()
  name: 'standard-tags-swa-app'
  params: {
    environment: environmentName
    project: projectCode
    service: serviceCode
    costCenter: costCenter
    createdBy: createdBy
    owner: owner
    ownerEmail: ownerEmail
  }
}

module containerAppNamingModule '../40-modules/core/naming.bicep' = {
  scope: subscription()
  name: 'container-app-naming'
  params: {
    projectCode: projectCode
    environment: environmentName
    serviceCode: serviceCode
    resourceType: 'ca'
  }
}

module swaNamingModule '../40-modules/core/naming.bicep' = {
  scope: subscription()
  name: 'swa-naming'
  params: {
    projectCode: projectCode
    environment: environmentName
    serviceCode: serviceCode
    resourceType: 'swa'
  }
}

// Dynamically add AZURE_CLIENT_ID to environment variables
var containerAppEnvironmentVariables = union(environmentVariables, [
  {
    name: 'AZURE_CLIENT_ID'
    value: uami.properties.clientId
  }
])

// ========== CONTAINER APP (using UAMI) ==========
module containerApp '../40-modules/core/container-app.bicep' = {
  name: 'containerApp'
  params: {
    containerAppName: containerAppNamingModule.outputs.resourceName
    environmentId: acaEnv.id
    image: containerImage
    location: resourceLocation
    tags: standardTagsModule.outputs.tags
    identity: {
      type: 'UserAssigned'
      userAssignedIdentities: {
        '${uami.id}': {}
      }
    }
    secrets: [for secret in keyVaultSecrets: {
      name: secret.name
      keyVaultUrl: secret.keyVaultUrl
      identity: uami.id
    }]
    registries: [
      {
        server: split(containerImage, '/')[0] // Extract ACR server from image
        identity: uami.id
      }
    ]
    environmentVariables: containerAppEnvironmentVariables
    secretEnvironmentVariables: secretEnvironmentVariables
    targetPort: 5000 // Flask app runs on port 5000
    externalIngress: true // Enable external access
    enableIngress: true
    ingressTransport: 'auto'
  }
}

// ========== STATIC WEB APP ==========
module staticWebApp '../40-modules/core/static-web-app.bicep' = {
  name: 'staticWebApp'
  params: {
    swaName: swaNamingModule.outputs.resourceName
    location: 'westeurope' // Static Web Apps aren't supported in Spain Central (yet)
    backendResourceId: containerApp.outputs.containerAppId // Link to Container App for API routing
    tags: standardTagsModule.outputs.tags
    sku: 'Standard' // Use Standard SKU for production features
    allowConfigFileUpdates: true
    provider: 'None' // Manual deployment, not from repository
    stagingEnvironmentPolicy: 'Enabled'
    enterpriseGradeCdnStatus: 'Disabled'
    linkedBackendName: 'containerapp'
  }
}

// ========== OUTPUTS ==========
output containerAppId string = containerApp.outputs.containerAppId
output containerAppName string = containerAppNamingModule.outputs.resourceName
output staticWebAppId string = staticWebApp.outputs.staticWebAppId
output staticWebAppName string = swaNamingModule.outputs.resourceName
output staticWebAppHostname string = staticWebApp.outputs.staticWebAppHostname
