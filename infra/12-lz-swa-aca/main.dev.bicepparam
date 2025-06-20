// Bicep parameters file for PaaS landing zone deployment
// This file configures the PaaS-specific landing zone infrastructure including:
// - PaaS spoke resource group
// - User-assigned managed identities for PaaS workloads
// - GitHub federated credentials for PaaS deployments
// - RBAC assignments for PaaS resources

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

// PaaS workload identities configuration
// These UAMIs will be used for PaaS workloads (Container Apps, Static Web Apps, etc.)
param workloadIdentities = {
  // Main PaaS workload identity with Contributor access to PaaS spoke RG
  paas: {
    UAMI: 'uami-ssharer-paas-dev'
    ENV: 'dev'
    ROLE: 'contributor'
    federationTypes: 'environment'
  }
}
