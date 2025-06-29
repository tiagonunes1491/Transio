/*
 * =============================================================================
 * Kubernetes Federation Module
 * =============================================================================
 * 
 * This Bicep module creates federated identity credentials for Azure Kubernetes
 * Service (AKS) integration with User-Assigned Managed Identities. It enables
 * workload identity authentication allowing Kubernetes service accounts to
 * authenticate to Azure services without storing credentials.
 * 
 * ARCHITECTURE OVERVIEW:
 * ┌─────────────────────────────────────────────────────────────────────────┐
 * │                    Kubernetes Federation Architecture                   │
 * ├─────────────────────────────────────────────────────────────────────────┤
 * │  Azure Active Directory                                                 │
 * │  ┌─────────────────────────────────────────────────────────────────────┐│
 * │  │ User-Assigned Managed Identity                                      ││
 * │  │ ┌─────────────────────┐  ┌─────────────────────────────────────┐   ││
 * │  │ │ Principal ID        │  │ Federated Identity Credential       │   ││
 * │  │ │ • Azure identity    │──│ • OIDC issuer trust                 │   ││
 * │  │ │ • OAuth2 tokens     │  │ • Subject mapping                   │   ││
 * │  │ └─────────────────────┘  └─────────────────────────────────────┘   ││
 * │  └─────────────────────────────────────────────────────────────────────┘│
 * │                                                                         │
 * │  Azure Kubernetes Service                                               │
 * │  ┌─────────────────────────────────────────────────────────────────────┐│
 * │  │ Workload Identity                                                   ││
 * │  │ ┌─────────────────────┐  ┌─────────────────────────────────────┐   ││
 * │  │ │ Service Account     │  │ OIDC Token Exchange                 │   ││
 * │  │ │ • Namespace scoped  │──│ • Secure authentication             │   ││
 * │  │ │ • Token projection  │  │ • Azure service access              │   ││
 * │  │ └─────────────────────┘  └─────────────────────────────────────┘   ││
 * │  └─────────────────────────────────────────────────────────────────────┘│
 * └─────────────────────────────────────────────────────────────────────────┘
 * 
 * SUBJECT FORMAT:
 * system:serviceaccount:{namespace}:{serviceAccountName}
 * 
 * SECURITY FEATURES:
 * • OIDC issuer validation
 * • Token audience verification  
 * • Subject claim mapping
 * • Short-lived token exchange
 */

@description('Name of the UAMI that will be federated')
param parentUserAssignedIdentityName  string

@description('Name of the Service Account that will be federated')
param serviceAccountName string

@description('Name of the namespace where the service account is located')
param serviceAccountNamespace string
@description('OIDC Issuer URL for the AKS cluster')
param oidcIssuerUrl string

@description('OIDC Audience for the federated credential. Defaults to Azure AD token exchange audience')
param oidcAudience array = [
  'api://AzureADTokenExchange' 
  ]

// Creates the subject name for the federated credential
// Format follows Kubernetes convention: system:serviceaccount:{namespace}:{name}
var subject = 'system:serviceaccount:${serviceAccountNamespace}:${serviceAccountName}'

// Generates a name for the federated credential
// Format: fic-{serviceAccountName}
var generatedFicName = 'fic-${serviceAccountName}' 


resource parentIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: parentUserAssignedIdentityName
}


resource oidcFederatedCredential 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2024-11-30' = {
  name: generatedFicName
  parent: parentIdentity
  properties: {
    issuer: oidcIssuerUrl
    audiences: oidcAudience
    subject: subject
  }
}

output oidcFederatedCredentialId string = oidcFederatedCredential.id
output oidcFederatedCredentialName string = oidcFederatedCredential.name
