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
param managementResourceGroupName = 'rg-ssharer-mgmt-dev'
// Resource tagging
param tags = {
  Application: 'Secure Sharer'
  environment: 'dev'
}

// GitHub integration configuration
// Update these values with your actual GitHub organization and repository
param gitHubOrganizationName = 'tiagonunes1491'
param gitHubRepositoryName = 'SecureSharer'

// Shared artifacts resource group (must be created by landing-zone-shared.bicep first)
param sharedArtifactsResourceGroupName = 'rg-ssharer-artifacts-hub'

// K8S workload identities configuration
// These UAMIs will be used for K8S workloads and deployments
param workloadIdentities = {
  // Main K8S workload identity with Contributor access to K8S spoke RG
  k8s: {
    UAMI: 'uami-ssharer-k8s-dev'
    ENV: 'dev'
    ROLE: 'contributor'
    federationTypes: 'environment'
  }
  // K8S deployment identity with ACR Pull access for container image pulls
  k8sDeploy: {
    UAMI: 'uami-ssharer-k8s-deploy-dev'
    ENV: 'dev'
    ROLE: 'AcrPull'
    federationTypes: 'environment'
  }
}
