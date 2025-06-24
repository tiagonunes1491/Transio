/*
 * =============================================================================
 * AKS Workload Identity Federation Module for Secure Secret Sharer
 * =============================================================================
 * 
 * This Bicep module creates federated identity credentials for Kubernetes
 * service accounts to authenticate with Azure services. It implements workload
 * identity patterns that eliminate the need for stored credentials in
 * Kubernetes pods while providing secure Azure service access.
 * 
 * ARCHITECTURE OVERVIEW:
 * ┌─────────────────────────────────────────────────────────────────────────┐
 * │                Workload Identity Federation                             │
 * ├─────────────────────────────────────────────────────────────────────────┤
 * │  Kubernetes Pod                                                         │
 * │  ┌─────────────────────────────────────────────────────────────────────┐│
 * │  │ Service Account Token                                               ││
 * │  │ ┌─────────────────────┐  ┌─────────────────────────────────────┐   ││
 * │  │ │ JWT Token           │  │ OIDC Claims                         │   ││
 * │  │ │ • Kubernetes issued │  │ • Namespace                         │   ││
 * │  │ │ • Service account   │  │ • Service account name              │   ││
 * │  │ │ • Pod identity      │  │ • Cluster issuer                    │   ││
 * │  │ └─────────────────────┘  └─────────────────────────────────────┘   ││
 * │  │                               │                                     ││
 * │  └───────────────────────────────┼─────────────────────────────────────┘│
 * │                                  ▼                                      │
 * │  Azure AD Token Exchange                                                │
 * │  ┌─────────────────────────────────────────────────────────────────────┐│
 * │  │ Federated Credential Validation                                     ││
 * │  │ ┌─────────────────────┐  ┌─────────────────────────────────────┐   ││
 * │  │ │ OIDC Validation     │  │ Azure AD Token                      │   ││
 * │  │ │ • Issuer check      │  │ • Access token generation           │   ││
 * │  │ │ • Audience match    │  │ • UAMI impersonation               │   ││
 * │  │ │ • Subject claim     │  │ • Azure service access             │   ││
 * │  │ └─────────────────────┘  └─────────────────────────────────────┘   ││
 * │  └─────────────────────────────────────────────────────────────────────┘│
 * └─────────────────────────────────────────────────────────────────────────┘
 * 
 * KEY FEATURES:
 * • Workload Identity: Native Kubernetes service account to Azure AD integration
 * • Zero Credentials: No stored secrets or certificates in Kubernetes
 * • OIDC Integration: Standards-based token exchange using OpenID Connect
 * • Namespace Isolation: Service account federation scoped to specific namespaces
 * • Automatic Token Refresh: Kubernetes handles token lifecycle automatically
 * • Multi-Service Support: Single UAMI can be federated to multiple service accounts
 * 
 * SECURITY CONSIDERATIONS:
 * • Eliminates credential storage in Kubernetes reducing attack surface
 * • Short-lived tokens with automatic rotation and renewal
 * • Subject claim validation ensures only authorized service accounts authenticate
 * • Namespace-based isolation prevents cross-namespace identity access
 * • OIDC issuer validation prevents token spoofing and replay attacks
 * • Comprehensive audit logging for all workload identity operations
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
