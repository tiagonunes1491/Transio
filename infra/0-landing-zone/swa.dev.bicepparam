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
param projectCode = 'ts'
param serviceCode = 'swa'

// Tagging information
param costCenter = '1000'
param createdBy = 'bicep-deployment'
param owner = ''
param ownerEmail = ''

// GitHub integration configuration
// Update these values with your actual GitHub organization and repository
param gitHubOrganizationName = ''
param gitHubRepositoryName = ''

// PaaS workload identities configuration
// These UAMIs will be used for PaaS workloads (Container Apps, Static Web Apps, etc.)
param workloadIdentities = {
  // Main PaaS workload identity with Contributor access to PaaS spoke RG
  contributor: {
    ENV: 'swa-dev-protected'
    ROLE: 'contributor'
    federationTypes: 'environment'
  }
  acrPush: {
        ENV: 'swa-dev'
        ROLE: 'AcrPush'
        federationTypes: 'environment'
    }
}
