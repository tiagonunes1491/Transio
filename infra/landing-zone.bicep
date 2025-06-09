// main.bicep - The Orchestrator for landing zone deployment for one environment
targetScope = 'subscription'

@description('Environment for the deployment')
param environmentName string = 'dev'

@description('Location for the resources')
param location string = 'spaincentral' // Default location, can be overridden

@description('Tags for resources')
param tags object = {
  Application: 'Secure Sharer'
  environment: environmentName
}

@description('GitHub organization name to federate with')
param gitHubOrganizationName string

@description('GitHub repository name to federate with')
param gitHubRepositoryName string

@description('GitHub subject pattern to federate with')
param gitHubSubjectPattern string = 'refs/heads/main'

// Create all resource groups for landing zone

resource artifactsRG 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-ssharer-artifacts-${environmentName}'
  location: location
  tags: tags
}

resource hubRG 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-ssharer-shared'
  location: location
  tags: {
    Application: 'Secure Sharer'
    environment: 'Shared Artifacts' 
  }
}

resource k8sRG 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-ssharer-k8s-${environmentName}'
  location: location
  tags: tags
}

resource swaRG 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-ssharer-swa-${environmentName}'
  location: location
  tags: tags
}


// Create workload UAMI to federate with GitHub Actions
// Assigns the required permissions to the UAMI to do operations


// --- 1. Create User Assigned Managed Identity (UAMI) for ACR ---

module uamiACR 'common-modules/uami.bicep' = {
  scope: hubRG
  params: {
    uamiLocation: location
    uamiNames: ['uami-ssharer-acr-${environmentName}']
    tags: tags
  }
}

// Federate UAMI with GitHub Actions
module githubFederation 'common-modules/github-federation.bicep' = {
  name: 'github-federation'
  scope: hubRG
  params: {
    UamiName: uamiACR.outputs.uamiNames[0]
    GitHubOrganizationName: gitHubOrganizationName
    GitHubRepositoryName: gitHubRepositoryName
    gitHubSubjectPattern: gitHubSubjectPattern
  }
}

// Assign the AcrPush role to the UAMI in the shared resource group

var acrPushRoleDefinitionId = '8311e382-0749-4cb8-b61a-304f252e45ec' // AcrPush role definition ID

module uami_acr_push 'common-modules/uami-rbac.bicep'= {
  scope: hubRG
  params: {
    uamiPrincipalId: uamiACR.outputs.uamiClientIds[0] // Use the first UAMI client ID
    roleDefinitionId: acrPushRoleDefinitionId
    scope: hubRG.id // Scope to the shared resource group
  }
} 

