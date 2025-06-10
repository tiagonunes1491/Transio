@description('Name of the existing UAMI to federate with GitHub Actions')
param UamiName string

@description('Name of the GitHub organization to federate with')
param GitHubOrganizationName string

@description('Name of the GitHub repository to federate with')
param GitHubRepositoryName string

@description('GitHub environment, branch or pattern to federate with')
param gitHubSubjectPattern string

@description('Name for the federated identity credential')
param federatedCredentialName string = 'github-federation'

// Reference the existing User Assigned Managed Identity (UAMI)
resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: UamiName
}

// Create the GitHub federation resource
resource githubFederation 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2024-11-30' = {
  name: federatedCredentialName
  parent: uami
  properties: {
    issuer: 'https://token.actions.githubusercontent.com'
    audiences: [
      'api://AzureADTokenExchange'
    ]
    subject: 'repo:${GitHubOrganizationName}/${GitHubRepositoryName}:${gitHubSubjectPattern}'
  }
}

// Outputs for reference
output federatedCredentialId string = githubFederation.id
output federatedCredentialName string = githubFederation.name
output uamiClientId string = uami.properties.clientId
output uamiPrincipalId string = uami.properties.principalId
