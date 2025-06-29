/*
 * =============================================================================
 * Static Web Apps Landing Zone Infrastructure for Secure Secret Sharer
 * =============================================================================
 * 
 * This Bicep template creates the Static Web Apps (SWA) landing zone
 * infrastructure for the Secure Secret Sharer application. It establishes the
 * foundational identity and access management components needed for deploying
 * and managing Static Web Apps and Container Apps workloads.
 * 
 * ARCHITECTURE OVERVIEW:
 * ┌─────────────────────────────────────────────────────────────────────────┐
 * │                    Static Web Apps Landing Zone                         │
 * ├─────────────────────────────────────────────────────────────────────────┤
 * │  SWA Resource Group                                                     │
 * │  ┌─────────────────────────────────────────────────────────────────────┐│
 * │  │                                                                     ││
 * │  │  ┌─────────────────────┐  ┌─────────────────────────────────────┐  ││
 * │  │  │ User-Assigned       │  │ GitHub Federated                    │  ││
 * │  │  │ Managed Identities  │──│ Credentials                         │  ││
 * │  │  │                     │  │                                     │  ││
 * │  │  │ • Creator Identity  │  │ • Environment-based                 │  ││
 * │  │  │ • ACR Push Identity │  │ • Passwordless Authentication       │  ││
 * │  │  └─────────────────────┘  └─────────────────────────────────────┘  ││
 * │  │                                                                     ││
 * │  │  ┌─────────────────────────────────────────────────────────────────┐││
 * │  │  │ RBAC Role Assignments                                          │││
 * │  │  │ • Contributor permissions for infrastructure creation          │││
 * │  │  │ • AcrPush permissions for container registry operations        │││
 * │  │  └─────────────────────────────────────────────────────────────────┘││
 * │  └─────────────────────────────────────────────────────────────────────┘│
 * └─────────────────────────────────────────────────────────────────────────┘
 * 
 * KEY FEATURES:
 * • Single Resource Group: Centralized organization for SWA workload resources
 * • Managed Identities: Secure, keyless authentication for Azure services
 * • GitHub Federation: Passwordless CI/CD authentication from GitHub Actions
 * • RBAC: Principle of least privilege access control
 * • Naming Convention: Consistent, predictable resource naming
 * • Tagging Strategy: Comprehensive metadata for governance and cost tracking
 * 
 * SECURITY CONSIDERATIONS:
 * • Uses managed identities to eliminate credential management
 * • Implements federated identity for secure CI/CD without secrets
 * • Applies minimal RBAC permissions based on workload requirements
 * • Follows Azure Well-Architected security pillar guidelines
 * 
 * DEPLOYMENT SCOPE:
 * This template operates at subscription scope to create a single resource group
 * and manage subscription-level resources like managed identities.
 */
targetScope = 'subscription'

/*
 * =============================================================================
 * PARAMETERS
 * =============================================================================
 */

// ========== CORE DEPLOYMENT PARAMETERS ==========

@description('Target environment for deployment affecting resource configuration and naming')
@allowed(['dev', 'prod'])
param environmentName string = 'dev'

@description('Azure region for all resource deployments')
param location string = 'spaincentral'

@description('Short project identifier used in resource naming conventions')
param projectCode string = 'ss'

@description('Service identifier for this platform deployment')
param serviceCode string = 'swa'

// ========== GOVERNANCE AND TAGGING PARAMETERS ==========

@description('Cost center identifier for billing allocation and financial tracking')
param costCenter string = '1000'

@description('Deployment method identifier for tracking automation sources')
param createdBy string = 'bicep-deployment'

@description('Resource owner identifier for accountability and governance')
param owner string = 'tiago-nunes'

@description('Resource owner email for notifications and governance contacts')
param ownerEmail string = 'tiago.nunes@example.com'

@description('Creation date for resource tagging - automatically set to current UTC date')
param createdDate string = utcNow('yyyy-MM-dd')

// ========== GITHUB INTEGRATION PARAMETERS ==========

@description('GitHub organization name for federated credential configuration')
param gitHubOrganizationName string

@description('GitHub repository name for federated credential configuration')
param gitHubRepositoryName string

// ========== WORKLOAD IDENTITY CONFIGURATION ==========

@description('GitHub workload identities for shared resource infrastructure - each entry defines UAMI, environment, RBAC role, and federation types')
param workloadIdentities object = {
    creator: {
        UAMI: 'uami-ssharer-shared-infra-creator'
        ENV: 'shared-protected'
        ROLE: 'contributor'
        federationTypes: 'environment'
    }
    push: {
        UAMI: 'uami-ssharer-acr-push'
        ENV: 'shared'
        ROLE: 'AcrPush'
        federationTypes: 'environment'
    }
}


/*
 * =============================================================================
 * VARIABLES
 * =============================================================================
 */

// ========== ENVIRONMENT MAPPING ==========

var envMapping = {
  dev: 'd'      // Development environment
  prod: 'p'     // Production environment  
  shared: 's'   // Shared/common resources
}

// ========== RESOURCE GROUP NAMING ==========

var rgName = toLower('${projectCode}-${envMapping[environmentName]}-${serviceCode}-rg')

// ========== STANDARDIZED TAGGING ==========

var standardTags = {
  environment: environmentName
  project: projectCode
  service: serviceCode
  costCenter: costCenter
  createdBy: createdBy
  owner: owner
  ownerEmail: ownerEmail
  createdDate: createdDate
  managedBy: 'bicep'
  deployment: deployment().name
}

// ========== RBAC ROLE MAPPING ==========

var roleIdMap = {
  contributor: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'
  AcrPush: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/8311e382-0749-4cb8-b61a-304f252e45ec'
}


/*
 * =============================================================================
 * RESOURCE GROUP CREATION
 * =============================================================================
 */

// ========== SWA WORKLOAD RESOURCE GROUP ==========

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: rgName
  location: location
  tags: standardTags
}


/*
 * =============================================================================
 * MANAGED IDENTITIES AND FEDERATED CREDENTIALS
 * =============================================================================
 */

// ========== MANAGED IDENTITY NAMING ===========

module uamiNamingModules '../modules/shared/naming.bicep' = [
  for (item, i) in items(workloadIdentities): {
    name: 'uami-naming-${item.key}'
    scope: subscription()
    params: {
      projectCode: projectCode
      environment: 'shared'
      serviceCode: serviceCode
      resourceType: 'id'
      suffix: 'gh-${item.key}'
    }
  }
]

// ========== USER-ASSIGNED MANAGED IDENTITIES ===========

module uamiModules '../modules/identity/uami.bicep' = [for (item, i) in items(workloadIdentities): {
  name: 'deploy-uami-${item.key}'
  scope: rg
  params: {
    uamiLocation: location
    uamiNames: [uamiNamingModules[i].outputs.resourceName]
    tags: standardTags
  }
}]

// ========== GITHUB FEDERATED CREDENTIALS ===========

module envFederationModules '../modules/identity/github-federation.bicep' = [for (item, i) in items(workloadIdentities): if (contains(split(item.value.federationTypes, ','), 'environment')) {
  name: 'deploy-env-fed-${item.key}'
  scope: rg
  params: {
    UamiName: uamiModules[i].outputs.uamis[0].name
    GitHubOrganizationName: gitHubOrganizationName
    GitHubRepositoryName: gitHubRepositoryName
    environmentName: item.value.ENV
    fedType: 'environment'
    federatedCredentialName: 'gh-env-${item.value.ENV}-${item.key}'
  }
  dependsOn: [uamiModules[i]]
}]

/*
 * =============================================================================
 * RBAC ROLE ASSIGNMENTS
 * =============================================================================
 */

// ========== RESOURCE GROUP ROLE ASSIGNMENTS ===========

module rbacAssignments '../modules/identity/rbacRg.bicep' = [for (item, i) in items(workloadIdentities): {
  name: 'deploy-rbac-${item.key}'
  scope: rg
  params: {
    principalId: uamiModules[i].outputs.uamis[0].principalId
    roleDefinitionId: roleIdMap[item.value.ROLE]
  }
  dependsOn: [uamiModules[i]]
}]

/*
 * =============================================================================
 * OUTPUTS
 * =============================================================================
 */

// ========== MANAGED IDENTITY OUTPUTS ==========

@description('Array of all created User-Assigned Managed Identity names for workload authentication')
output uamiNames array = [
  for (item, i) in items(workloadIdentities): uamiModules[i].outputs.uamis[0].name
]

@description('Array of all User-Assigned Managed Identity principal IDs for RBAC role assignments')
output uamiPrincipalIds array = [
  for (item, i) in items(workloadIdentities): uamiModules[i].outputs.uamis[0].principalId
]

@description('Array of federated credential names for GitHub Actions integration')
output federatedCredentialNames array = [
  for (item, i) in items(workloadIdentities): contains(split(item.value.federationTypes, ','), 'environment') ? 'gh-env-${item.value.ENV}-${item.key}' : ''
]

// ========== RESOURCE GROUP OUTPUTS ==========

@description('SWA resource group name for workload deployments')
output resourceGroupName string = rg.name

// ========== AZURE ENVIRONMENT OUTPUTS ==========

@description('Azure AD tenant ID for identity federation configuration')
output tenantId string = subscription().tenantId

@description('Azure subscription ID for resource deployment targeting')
output subscriptionId string = subscription().subscriptionId

@description('Environment name for configuration and deployment logic')
output environmentName string = environmentName

