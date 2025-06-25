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

// PaaS workload identities configuration
// These UAMIs will be used for PaaS workloads (Container Apps, Static Web Apps, etc.)
param workloadIdentities = {
  // Main PaaS workload identity with Contributor access to PaaS spoke RG
  contributor: {
    ENV: 'aks-dev-protected'
    ROLE: 'contributor'
    federationTypes: 'environment'
  }
  acrPush: {
        ENV: 'aks-dev'
        ROLE: 'AcrPush'
        federationTypes: 'environment'
    }
}
