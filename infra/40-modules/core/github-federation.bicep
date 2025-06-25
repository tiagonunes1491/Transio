/*
 * =============================================================================
 * GitHub Federation Module for Secure Secret Sharer
 * =============================================================================
 * 
 * This Bicep module creates federated identity credentials for GitHub Actions
 * to authenticate with Azure using OpenID Connect (OIDC). It enables secure,
 * passwordless authentication from GitHub workflows to Azure resources using
 * User-Assigned Managed Identities, eliminating the need for stored credentials.
 * 
 * ARCHITECTURE OVERVIEW:
 * ┌─────────────────────────────────────────────────────────────────────────┐
 * │                GitHub Federation Architecture                            │
 * ├─────────────────────────────────────────────────────────────────────────┤
 * │  GitHub Actions Workflow                                                │
 * │  ┌─────────────────────────────────────────────────────────────────────┐│
 * │  │ OIDC Token Request                                                  ││
 * │  │ ┌─────────────────────┐  ┌─────────────────────────────────────┐   ││
 * │  │ │ Workflow Context    │  │ Token Claims                        │   ││
 * │  │ │ • Repository        │  │ • Subject (branch/environment)      │   ││
 * │  │ │ • Branch/Environment│  │ • Issuer (GitHub OIDC)             │   ││
 * │  │ │ • Workflow trigger  │  │ • Audience (Azure AD)               │   ││
 * │  │ └─────────────────────┘  └─────────────────────────────────────┘   ││
 * │  │                               │                                     ││
 * │  └───────────────────────────────┼─────────────────────────────────────┘│
 * │                                  ▼                                      │
 * │  Azure AD Verification                                                  │
 * │  ┌─────────────────────────────────────────────────────────────────────┐│
 * │  │ Federated Credential Validation                                     ││
 * │  │ ┌─────────────────────┐  ┌─────────────────────────────────────┐   ││
 * │  │ │ Token Verification  │  │ Identity Mapping                    │   ││
 * │  │ │ • Issuer validation │  │ • UAMI association                  │   ││
 * │  │ │ • Subject matching  │  │ • Principal ID mapping              │   ││
 * │  │ │ • Audience check    │  │ • Azure token generation            │   ││
 * │  │ └─────────────────────┘  └─────────────────────────────────────┘   ││
 * │  └─────────────────────────────────────────────────────────────────────┘│
 * └─────────────────────────────────────────────────────────────────────────┘
 * 
 * KEY FEATURES:
 * • Passwordless Authentication: No stored credentials in GitHub secrets
 * • Flexible Federation Types: Support for branch-based and environment-based authentication
 * • OIDC Integration: Industry-standard OpenID Connect for secure token exchange
 * • Granular Control: Specific repository and branch/environment targeting
 * • Audit Trail: Complete audit log of all authentication events
 * • Zero Trust Security: Continuous verification of identity claims
 * • CI/CD Optimization: Seamless integration with GitHub Actions workflows
 * 
 * SECURITY CONSIDERATIONS:
 * • Eliminates credential storage reducing attack surface and credential theft risk
 * • Short-lived tokens with automatic expiration for enhanced security
 * • Subject claim validation ensures only authorized workflows can authenticate
 * • Issuer verification prevents token replay and manipulation attacks
 * • Audience restriction limits token usage to intended Azure AD tenants
 * • Comprehensive audit logging for security monitoring and compliance
 * 
 * DEPLOYMENT SCOPE:
 * This module operates at resource group scope to create federated
 * identity credentials that link GitHub Actions workflows to Azure
 * User-Assigned Managed Identities for secure CI/CD operations.
 */
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
var subjectFilter = (fedType == 'environment') ? 'environment:${environmentName}' : 'ref:refs/heads/${branchName}'

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
