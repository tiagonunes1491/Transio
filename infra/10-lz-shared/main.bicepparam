// Bicep parameters file for shared landing zone deployment
// This file configures the shared landing zone infrastructure including:
// - Shared artifacts resource group
// - Shared management identities
// - GitHub federated credentials for shared infrastructure
// - ACR push permissions for container image publishing

using 'main.bicep'

// Environment configuration
@description('Location for the resources')
param location = 'spaincentral' // Default location, can be overridden

@description('Project code')
param projectCode = 'ss'

@description('Service code for shared services')
param serviceCode = 'plat'

@description('Cost center for billing')
param costCenter = '1000'

@description('Created by information')
param createdBy = 'bicep-deployment'

@description('Owner')
param owner = 'tiago-nunes'

@description('Owner email')
param ownerEmail = 'tiago.nunes@example.com'

// GitHub integration configuration
@description('GitHub organization name to federate with')
param gitHubOrganizationName = 'tiagonunes1491'

@description('GitHub repository name to federate with')
param gitHubRepositoryName = 'SecureSharer'

// Shared workload identities configuration
@description('GitHub workload identities for the shared resources infrastructure. Each entry defines a UAMI, its environment, RBAC role, and federation types.')
param workloadIdentities = {
    contributor: {
        UAMI: 'uami-ssharer-shared-infra-creator'
        ENV: 'shared-protected'
        ROLE: 'contributor'
        federationTypes: 'environment'
    }
    acrPush: {
        UAMI: 'uami-ssharer-acr-push'
        ENV: 'shared'
        ROLE: 'AcrPush'
        federationTypes: 'environment'
    }
}
