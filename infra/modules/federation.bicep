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
