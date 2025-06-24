// Module: core/github-federation.bicep
// Description: Creates federated identity credentials for GitHub Actions to authenticate with Azure using OpenID Connect (OIDC).
// Enables secure, passwordless authentication from GitHub workflows to Azure resources using User Assigned Managed Identities.
// Supports both branch-based and environment-based federation scenarios for flexible CI/CD pipeline authentication.
//
// Parameters:
//   - UamiName: Name of the existing User Assigned Managed Identity to federate with
//   - GitHubOrganizationName: GitHub organization name containing the repository
//   - GitHubRepositoryName: GitHub repository name for federation
//   - branchName: Git branch name for branch-based federation (default: main)
//   - environmentName: GitHub environment name for environment-based federation (default: production)
//   - federatedCredentialName: Name for the federated credential resource (default: github-federation)
//   - fedType: Federation type - either 'environment' or 'branch' (default: branch)
//
// Resources Created:
//   - Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials: The federated credential linking GitHub to Azure
//
// Federation Types:
//   - Branch: Allows authentication from specific Git branches (subject: repo:org/repo:ref:refs/heads/branch)
//   - Environment: Allows authentication from GitHub environments (subject: repo:org/repo:environment:env-name)
//
// Outputs:
//   - federatedCredentialId: Resource ID of the created federated credential
//   - federatedCredentialName: Name of the created federated credential
//   - uamiClientId: Client ID of the User Assigned Managed Identity
//   - uamiPrincipalId: Principal ID of the User Assigned Managed Identity
//
// Usage:
//   Use this module to establish secure OIDC-based authentication between GitHub Actions workflows and Azure.
//   Eliminates the need for storing Azure credentials as GitHub secrets.
//
// Example:
//   module githubFed 'core/github-federation.bicep' = {
//     name: 'github-federation'
//     scope: resourceGroup()
//     params: {
//       UamiName: 'my-identity'
//       GitHubOrganizationName: 'myorg'
//       GitHubRepositoryName: 'myrepo'
//       fedType: 'environment'
//       environmentName: 'production'
//     }
//   }

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

// Construct the OIDC subject claim based on federation type
// Branch federation: Allows access from specific Git branches (e.g., main, develop)
// Environment federation: Allows access from GitHub deployment environments (e.g., production, staging)
var subjectFilter = fedType == 'environment'
  ? 'environment:${environmentName}'
  : 'ref:refs/heads/${branchName}'

// Reference the existing User Assigned Managed Identity that will be federated
resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: UamiName
}

// Create the federated identity credential that establishes the trust relationship
// between GitHub Actions (OIDC provider) and the Azure User Assigned Managed Identity
resource githubFederation 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-07-31-preview' = {
  name: federatedCredentialName
  parent: uami
  properties: {
    // GitHub Actions OIDC issuer endpoint
    issuer: 'https://token.actions.githubusercontent.com'
    // Azure AD audience for token exchange
    audiences: [
      'api://AzureADTokenExchange'
    ]
    // OIDC subject claim that uniquely identifies the GitHub workflow context
    // Format: repo:organization/repository:filter
    // Where filter is either environment:env-name or ref:refs/heads/branch-name
    subject: 'repo:${GitHubOrganizationName}/${GitHubRepositoryName}:${subjectFilter}'
  }
}

// Outputs for reference
output federatedCredentialId string = githubFederation.id
output federatedCredentialName string = githubFederation.name
output uamiClientId string = uami.properties.clientId
output uamiPrincipalId string = uami.properties.principalId
