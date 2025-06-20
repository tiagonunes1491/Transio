// Bicep parameters file for K8S landing zone deployment
// This file configures the K8S-specific landing zone infrastructure including:
// - K8S spoke resource group
// - User-assigned managed identities for K8S workloads
// - GitHub federated credentials for K8S deployments
// - RBAC assignments for K8S resources

using 'main.bicep'

// Environment configuration
param environmentName = 'dev'
param location = 'spaincentral'

// Project and service identification
param projectCode = 'ss'
param serviceCode = 'aks'

// Tagging information
param costCenter = '1000'
param createdBy = 'bicep-deployment'
param owner = 'tiago-nunes'
param ownerEmail = 'tiago.nunes@example.com'

// GitHub integration configuration
// Update these values with your actual GitHub organization and repository
param gitHubOrganizationName = 'tiagonunes1491'
param gitHubRepositoryName = 'SecureSharer'

// K8S workload identities configuration
// These UAMIs will be used for K8S workloads and deployments
param workloadIdentities = {
  // Main K8S workload identity with Contributor access to K8S spoke RG
  k8s: {
    UAMI: 'k8s'
    ENV: 'dev'
    ROLE: 'contributor'
    federationTypes: 'environment'
  }
  // K8S deployment identity with ACR Pull access for container image pulls
  k8sDeploy: {
    UAMI: 'k8s-deploy'
    ENV: 'dev'
    ROLE: 'AcrPull'
    federationTypes: 'environment'
  }
}
