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

// Assign RBAC roles to the UAMI at subscription scope
module uamiRbacContributor 'common-modules/uami-rbac.bicep' = {
  name: 'uamiRbacContributorDeployment' // Unique deployment name
  scope: subscription()
  params: {
    uamiPrincipalId: uami.outputs.uamiClientIds[0] // Corrected output name assuming uami module outputs principalId
    roleDefinitionId: 'b24988ac-6180-42a0-ab88-20f7382dd24c' // Contributor
    roleAssignmentDescription: 'Assign Contributor role to UAMI at subscription scope for GitHub Actions'
  }
}

module uamiRbacUserAccessAdmin 'common-modules/uami-rbac.bicep' = {
  name: 'uamiRbacUserAccessAdminDeployment' // Unique deployment name
  scope: subscription()
  params: {
    uamiPrincipalId: uami.outputs.uamiClientIds[0] // Corrected output name
    roleDefinitionId: '18d7d88d-d35e-4fb5-b5fe-f241ba7cc854' // User Access Administrator
    roleAssignmentDescription: 'Assign User Access Administrator role to UAMI at subscription scope for GitHub Actions'
  }

}

module uamiRbacManagedIdentityContributor 'common-modules/uami-rbac.bicep' = {
  name: 'uamiRbacManagedIdentityContributorDeployment' // Unique deployment name
  scope: subscription()
  params: {
    uamiPrincipalId: uami.outputs.uamiClientIds[0] // Corrected output name
    roleDefinitionId: 'e40ec5ca-96e0-45a2-b4ff-59039f2c2b59' // Managed Identity Contributor
    roleAssignmentDescription: 'Assign Managed Identity Contributor role to UAMI at subscription scope for GitHub Actions'
  }
}

// Output the UAMI principal ID for reference
output uamiPrincipalId string = uami.outputs.uamiClientIds[0] // Corrected output name
output resourceGroupName string = bootstrapRg.name
output resourceGroupLocation string = bootstrapRg.location
