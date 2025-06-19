// main.bicep
// This deploys the entire platform with stubbed ACA and SWA, ready for CI/CD artifact delivery

// ========== PARAMETERS ==========
targetScope = 'subscription'

@description('Azure location')
param location string = 'westeurope'

@description('Resource Group Name')
param rgName string = 'rg-secure-sharer-swa-aca-dev'

@description('Cosmos DB Info')
param cosmosDbAccountName string
param cosmosDbEndpoint string
param cosmosDatabaseName string = 'SecureSharer'
param cosmosContainerName string = 'secrets'
param sharedResourceGroupName string

@description('Tag object')
param tags object

@description('Key Vault secrets object (secure)')
@secure()
param akvSecrets object

@description('ACR name')
param acrName string

// ========== RESOURCE GROUP ==========
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: rgName
  location: location
  tags: tags
}

// ========== MODULES ==========
module network 'common-modules/network.bicep' = {
  name: 'network'
  scope: rg
  params: {
    vnetName: 'vnet-secureSecretSharer'
    location: location
    addressSpace: [ '10.0.0.0/16' ]
    subnets: [
      {
        name: 'snet-aca'
        addressPrefix: '10.0.10.0/23'
      }
      {
        name: 'snet-pe'
        addressPrefix: '10.0.30.0/24'
        privateEndpointNetworkPolicies: 'Disabled'
      }
      {
        name: 'snet-aci'
        addressPrefix: '10.0.40.0/24'
        serviceEndpoints: [
          {
            service: 'Microsoft.Storage'
          }
        ]
        delegations: [
          {
            name: 'aciDelegation'
            properties: {
              serviceName: 'Microsoft.ContainerInstance/containerGroups'
            }
          }
        ]
      }
    ]
  }
}

module keyvault 'common-modules/keyvault.bicep' = {
  name: 'keyvault'
  scope: rg
  params: {
    keyvaultName: 'kv-sec-secret-sharer'
    location: location
    sku: 'standard'
    tenantId: subscription().tenantId
    enableRbac: true
    enablePurgeProtection: true
    secretsToSet: akvSecrets
    tags: tags
  }
}

module acr 'shared-infra-modules/acr.bicep' = {
  name: 'acr'
  scope: rg
  params: {
    acrName: acrName
    location: location
    sku: 'Standard'
    enableAdminUser: false
    tags: tags
  }
}

module workspace 'common-modules/workspace.bicep' = {
  name: 'workspace'
  scope: rg
  params: {
    workspaceName: 'ws-sec-sharer'
    location: location
    tags: tags
  }
}

module acaEnv 'swa-aca-modules/aca-environment.bicep' = {
  name: 'acaEnvironment'
  scope: rg
  params: {
    acaEnvironmentName: 'cae-sharer-aca-dev'
    acaEnvironmentLocation: location
    workspaceId: workspace.outputs.workspaceId
    acaEnvironmentTags: tags
    acaEnvironmentSubnetId: network.outputs.subnetIds[0]
  }
}

module uami 'common-modules/uami.bicep' = {
  name: 'uami'
  scope: rg
  params: {
    uamiLocation: location
    uamiNames: [ 'aca-sharer-identity' ]
    tags: tags
  }
}

// ========== ACA & SWA STUBS (no image or repo here, only placeholders) ==========
module acaStub 'swa-aca-app/main.bicep' = {
  name: 'acaStub'
  scope: rg
  params: {
    appName: 'secure-secret-sharer-aca-dev'
    appLocation: location
    containerImage: '${acr.outputs.acrLoginServer}/stub:latest'
    environmentId: acaEnv.outputs.acaEnvironmentId
    userAssignedIdentityId: uami.outputs.uamiIds[0]
    acrLoginServer: acr.outputs.acrLoginServer
    keyVaultUri: keyvault.outputs.keyvaultUri
    keyVaultSecrets: akvSecrets
    tags: tags
    cosmosDbEndpoint: cosmosDbEndpoint
    cosmosDatabaseName: cosmosDatabaseName
    cosmosContainerName: cosmosContainerName
    acaCpuLimit: '0.25'
    acaMemoryLimit: '0.5Gi'
  }
}

module swaStub 'swa-aca-frontend/main.bicep' = {
  name: 'swaStub'
  scope: rg
  params: {
    staticWebAppName: 'swa-secure-secret-sharer'
    location: location
    tag: tags
    repositoryUrl: ''
    branch: 'main'
    backendApiResourceId: acaStub.outputs.acaAppId
  }
}
