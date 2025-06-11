@description('Name of the existing UAMI to federate with GitHub Actions')
param UamiName string

@description('Name of the GitHub organization to federate with')
param GitHubOrganizationName string

@description('Name of the GitHub repository to federate with')
param GitHubRepositoryName string

@description('GitHub branch name (e.g., main)')
param branchName string = 'main'

@description('GitHub environment to federate with')
param environmentName string = 'production'

@description('Name for the federated identity credential')
param federatedCredentialName string = 'github-federation'

@description('Type of federated identity credential. Can be "environment" or "branch".')
@allowed([
  'environment'
  'branch'
])
param fedType string = 'branch'

// Correctly constructs the subject filter based on the federation type.
var subjectFilter = fedType == 'environment'
  ? 'environment:${environmentName}'
  : 'ref:refs/heads/${branchName}'

// Reference the existing User Assigned Managed Identity (UAMI)
resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: UamiName
}

// Create the GitHub federation resource
resource githubFederation 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-07-31-preview' = {
  name: federatedCredentialName
  parent: uami
  properties: {
    issuer: 'https://token.actions.githubusercontent.com'
    audiences: [
      'api://AzureADTokenExchange'
    ]
    subject: 'repo:${GitHubOrganizationName}/${GitHubRepositoryName}:${subjectFilter}'
  }
}

// Outputs for reference
output federatedCredentialId string = githubFederation.id
output federatedCredentialName string = githubFederation.name
output uamiClientId string = uami.properties.clientId
output uamiPrincipalId string = uami.properties.principalId
