// Creates a UAMI and federates it with GitHub Actions for CI/CD workflow bootstrapping
// This will allow GithHub Actions to use the UAMI for a land zone CI/CD.
targetScope = 'subscription'

@description('Environment for the deployment')
param environment string = 'dev'

@description('Location for the resources')
param location string = 'spaincentral'

@description('Name of the User Assigned Managed Identity (UAMI) to create')
param uamiName string = 'uami-github-bootstrap'

@description('GitHub organization name to federate with')
param gitHubOrganizationName string

@description('GitHub repository name to federate with')
param gitHubRepositoryName string

@description('GitHub subject pattern to federate with')
param gitHubSubjectPattern string = 'refs/heads/main'

@description('Name of the security group for GitHub Actions managed identities')
param securityGroupName string = 'sg-github-actions-${environment}'

@description('Tags for resources')
param tags object = {
  purpose: 'github-actions'
  environment: environment
}

// Create a resource group for the environment management
resource bootstrapRg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-ssharer-mgmt-${environment}'
  location: location
  tags: tags
}

// Deploy UAMI to bootstrap GitHub Actions
module uami 'common-modules/uami.bicep' = {
  scope: bootstrapRg
  params: {
    uamiLocation: location
    uamiNames: [uamiName]
    tags: tags
  }
}

// Federate UAMI with GitHub Actions
module githubFederation 'common-modules/github-federation.bicep' = {
  name: 'github-federation'
  scope: bootstrapRg
  params: {
    UamiName: uamiName
    GitHubOrganizationName: gitHubOrganizationName
    GitHubRepositoryName: gitHubRepositoryName
    gitHubSubjectPattern: gitHubSubjectPattern
  }
  dependsOn: [
    uami
  ]
}

// Output the UAMI principal ID for reference
output uamiPrincipalId string = uami.outputs.uamiClientIds[0] // Corrected output name
output resourceGroupName string = bootstrapRg.name
output resourceGroupLocation string = bootstrapRg.location
output tenantId string = subscription().tenantId // Output the tenant ID for reference
output subscriptionId string = subscription().subscriptionId // Output the subscription ID for reference
