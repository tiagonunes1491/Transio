/*
 * =============================================================================
 * Shared Landing Zone Infrastructure for Secure Secret Sharer
 * =============================================================================
 * 
 * This Bicep template establishes the foundational shared infrastructure for
 * the Secure Secret Sharer project. It creates the core landing zone components
 * that support multiple workloads and environments with secure, scalable,
 * and well-governed identity management.
 * 
 * ARCHITECTURE OVERVIEW:
 * ┌─────────────────────────────────────────────────────────────────────────┐
 * │                       Shared Landing Zone                               │
 * ├─────────────────────────────────────────────────────────────────────────┤
 * │  Management RG              │  Shared Hub RG                            │
 * │  ┌─────────────────────┐   │  ┌─────────────────────────────────────┐  │
 * │  │ User-Assigned       │   │  │ Shared Services                     │  │
 * │  │ Managed Identities  │───┼──│ Container Registry                  │  │
 * │  │                     │   │  │ Key Vault                           │  │
 * │  │ GitHub Federation   │   │  │ Log Analytics                       │  │
 * │  │ Credentials         │   │  │ Application Insights                │  │
 * │  │                     │   │  │                                     │  │
 * │  │ RBAC Assignments    │   │  │ Platform Services                   │  │
 * │  └─────────────────────┘   │  └─────────────────────────────────────┘  │
 * └─────────────────────────────────────────────────────────────────────────┘
 * 
 * KEY FEATURES:
 * • Shared Foundation: Centralized infrastructure supporting multiple workloads
 * • Identity Management: Secure managed identities with GitHub federation
 * • RBAC Governance: Role-based access control with least privilege principles
 * • Multi-Environment Support: Flexible configuration for different deployment stages
 * • Container Registry Integration: Secure image storage with appropriate permissions
 * • Naming Standards: Consistent, predictable resource naming across environments
 * • Comprehensive Tagging: Full metadata strategy for governance and cost tracking
 * 
 * SECURITY CONSIDERATIONS:
 * • Zero-credential authentication through managed identities
 * • Federated identity integration with GitHub Actions for secure CI/CD
 * • Principle of least privilege RBAC assignments
 * • Separation of management and workload resources
 * • Built-in Azure security best practices implementation
 * • Audit trail through comprehensive tagging and deployment tracking
 * 
 * DEPLOYMENT SCOPE:
 * This template operates at subscription scope to create foundational
 * resource groups and manage cross-resource group identity assignments.
 */
targetScope = 'subscription'

/*
 * =============================================================================
 * PARAMETER DEFINITIONS
 * =============================================================================
 * 
 * These parameters configure the shared landing zone deployment, establishing
 * naming conventions, governance settings, and security configurations that
 * will be inherited by all dependent workloads.
 */

/*
 * INFRASTRUCTURE CONFIGURATION PARAMETERS
 * Core settings that define the deployment location and organizational structure
 */
@description('Azure region where shared infrastructure resources will be deployed')
param location string = 'spaincentral'

/*
 * ORGANIZATIONAL NAMING PARAMETERS
 * These parameters establish the naming hierarchy for all resources:
 * Pattern: {projectCode}-{environment}-{serviceCode}-{resourceType}
 */
@description('Project code - root identifier for the Secure Secret Sharer project')
param projectCode string = 'ss'

@description('Service code for shared platform services - identifies shared infrastructure components')
param serviceCode string = 'plat'

/*
 * GOVERNANCE AND COMPLIANCE PARAMETERS
 * Essential metadata for resource governance, cost management, and audit compliance
 */
@description('Cost center for billing allocation and financial tracking')
param costCenter string = '1000'

@description('Deployment method identifier - tracks infrastructure provisioning source')
param createdBy string = 'bicep-deployment'

@description('Primary resource owner - accountable person for these infrastructure components')
param owner string = 'tiago-nunes'

@description('Owner contact email - primary point of contact for operational issues')
param ownerEmail string = 'tiago.nunes@example.com'

@description('Resource creation timestamp - automatically populated with current UTC date')
param createdDate string = utcNow('yyyy-MM-dd')

/*
 * GITHUB INTEGRATION PARAMETERS
 * Configuration for establishing federated identity trust with GitHub Actions
 * Enables secure, passwordless authentication from CI/CD pipelines to Azure
 */
@description('GitHub organization name for federated credential configuration')
param gitHubOrganizationName string

@description('GitHub repository name for establishing OIDC trust relationship')
param gitHubRepositoryName string

/*
 * WORKLOAD IDENTITY CONFIGURATION
 * Defines the managed identities required for different shared infrastructure operations
 * Each identity is configured with specific roles and federation capabilities
 * 
 * Structure Explanation:
 * - Key: Logical identifier for the workload type (e.g., 'creator', 'push')
 * - ENV: GitHub environment name for federation scope
 * - ROLE: Azure RBAC role to assign (maps to built-in role definitions)
 * - federationTypes: Authentication methods supported (comma-separated)
 * 
 * Default Configuration:
 * • creator: Full contributor access for infrastructure provisioning
 * • push: Container registry push permissions for image publishing
 */
@description('Workload identities for shared infrastructure operations with environment-specific roles and federation settings')
param workloadIdentities object = {
    creator: {
        ENV: 'shared-protected'        // Protected environment for infrastructure changes
        ROLE: 'contributor'            // Full resource management permissions
        federationTypes: 'environment' // GitHub environment-based authentication
    }
    push: {
        ENV: 'shared'                  // Standard environment for container operations
        ROLE: 'AcrPush'               // Container registry push permissions only
        federationTypes: 'environment' // GitHub environment-based authentication
    }
}

/*
 * =============================================================================
 * NAMING CONVENTION AND TAGGING STRATEGY
 * =============================================================================
 * 
 * Establishes consistent naming patterns and comprehensive tagging for all
 * shared infrastructure resources, ensuring governance and operational clarity.
 */

/*
 * ENVIRONMENT CODE MAPPING
 * Standardized abbreviations for environment names to ensure resource names
 * remain within Azure naming constraints while maintaining readability
 */
var envMapping = {
  dev: 'd'      // Development environment abbreviation
  prod: 'p'     // Production environment abbreviation
  shared: 's'   // Shared/common resources abbreviation
}

/*
 * CENTRALIZED NAMING MODULE FOR HUB RESOURCE GROUP
 * Uses the organization's standard naming module to ensure consistency
 * across all infrastructure components and compliance with naming policies
 */
module hubRgNamingModule '../40-modules/core/naming.bicep' = {
  name: 'rg-hub-naming'
  scope: subscription()
  params: {
    projectCode: projectCode
    environment: 'shared'
    serviceCode: serviceCode
    resourceType: 'rg'
  }
}

/*
 * RESOURCE GROUP NAMING VARIABLES
 * Direct naming for resource groups that need to be available at compile time
 * Follows the pattern: {projectCode}-{envCode}-{serviceCode}-{resourceType}
 * 
 * Examples:
 * - ss-s-plat-rg (Shared platform/hub resource group)
 * - ss-i-mgmt-rg (Infrastructure management resource group)
 */
var hubRgName = toLower('${projectCode}-${envMapping.shared}-${serviceCode}-rg')  // Central hub for shared services
var mgmtRgName = toLower('${projectCode}-i-mgmt-rg')                             // Management layer for identities

/*
 * COMPREHENSIVE TAGGING STRATEGY
 * Standardized tags applied to all resources for governance, cost allocation,
 * and operational management. These tags support automated policies and reporting.
 */
var standardTags = {
  environment: 'shared'                // Environment classification for shared resources
  project: projectCode                 // Project identifier for resource grouping
  service: serviceCode                 // Service component for logical organization
  costCenter: costCenter               // Financial allocation and chargeback tracking
  createdBy: createdBy                // Provisioning method for audit trails
  owner: owner                        // Accountability and primary contact
  ownerEmail: ownerEmail              // Operational contact information
  createdDate: createdDate            // Resource lifecycle tracking
  managedBy: 'bicep'                  // Infrastructure as Code tool identification
  deployment: deployment().name        // Specific deployment instance for troubleshooting
}


/*
 * =============================================================================
 * AZURE RBAC ROLE DEFINITIONS
 * =============================================================================
 * 
 * Maps logical role names to Azure built-in role definition IDs for consistent
 * and secure permission management across all workload identities.
 */

/*
 * ROLE DEFINITION MAPPING
 * Centralized mapping of workload roles to Azure built-in role definitions
 * Using built-in roles ensures security best practices and reduces maintenance overhead
 * 
 * Role Descriptions:
 * • Contributor: Full management access to resources (excludes access management)
 * • AcrPush: Azure Container Registry push permissions for image publishing
 */
var roleIdMap = {
  contributor: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c' // Contributor role for infrastructure management
  AcrPush: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/8311e382-0749-4cb8-b61a-304f252e45ec'     // AcrPush role for container registry operations
}

/*
 * =============================================================================
 * FOUNDATIONAL RESOURCE GROUPS
 * =============================================================================
 * 
 * Creates the core resource groups that form the foundation of the shared
 * landing zone, organizing resources by function and security requirements.
 */

/*
 * SHARED HUB RESOURCE GROUP
 * Central resource group hosting shared platform services that support
 * multiple workloads and environments across the entire solution
 * 
 * Typical contents:
 * • Azure Container Registry for centralized image storage
 * • Azure Key Vault for secrets and certificate management
 * • Log Analytics Workspace for centralized logging
 * • Application Insights for application performance monitoring
 * • Shared networking components (if applicable)
 */
resource hubRG 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: hubRgName
  location: location
  tags: standardTags
}

/*
 * SHARED MANAGEMENT RESOURCE GROUP
 * Dedicated resource group for identity and access management components
 * that require special security considerations and governance
 * 
 * Contains:
 * • User-Assigned Managed Identities (UAMIs) for all workloads
 * • Federated identity credentials for GitHub integration
 * • Cross-subscription identity resources (if needed)
 * 
 * Security rationale:
 * Separating identity resources provides better security boundaries,
 * enables specialized access controls, and follows defense-in-depth principles
 */
resource mgmtSharedRG 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: mgmtRgName
  location: location
  tags: standardTags
}

/*
 * =============================================================================
 * MANAGED IDENTITIES AND FEDERATED AUTHENTICATION
 * =============================================================================
 * 
 * Establishes secure, keyless authentication infrastructure for shared platform
 * operations. Creates managed identities and configures GitHub federation for
 * secure CI/CD without credential storage.
 */

/*
 * MANAGED IDENTITY NAMING GENERATION
 * Uses centralized naming module to generate consistent names for all UAMIs
 * Ensures compliance with organizational naming standards and policies
 * 
 * Naming Pattern: {projectCode}-{environment}-{serviceCode}-id-gh-{workloadType}
 * Example: ss-s-plat-id-gh-creator, ss-s-plat-id-gh-push
 */
module uamiNamingModules '../40-modules/core/naming.bicep' = [for item in items(workloadIdentities): {
  name: 'uami-naming-${item.key}'
  scope: subscription()
  params: {
    projectCode: projectCode
    environment: 'shared'
    serviceCode: serviceCode
    resourceType: 'id'
    suffix: 'gh-${item.key}'
  }
}]

/*
 * USER-ASSIGNED MANAGED IDENTITIES CREATION
 * Creates secure managed identities for each defined workload operation type
 * 
 * UAMI Benefits:
 * • Eliminates credential management and rotation overhead
 * • Provides automatic Azure AD integration
 * • Supports cross-resource authentication scenarios
 * • Enables audit trails for identity usage
 * • Integrates seamlessly with Azure RBAC
 * 
 * Each identity is created in the management resource group for centralized
 * governance and security management
 */
module uamiModules '../40-modules/core/uami.bicep' = [for (item, i) in items(workloadIdentities): {
  name: 'deploy-uami-${item.key}'
  scope: mgmtSharedRG
  params: {
    uamiLocation: location
    uamiNames: [uamiNamingModules[i].outputs.resourceName]
    tags: standardTags
  }
}]

/*
 * GITHUB FEDERATED IDENTITY CREDENTIALS
 * Establishes OIDC trust relationship between GitHub Actions and Azure AD
 * Enables secure, tokenless authentication from CI/CD pipelines
 * 
 * Federation Benefits:
 * • Zero secrets stored in GitHub repositories
 * • Short-lived, automatically rotated tokens
 * • Fine-grained access control per environment
 * • Compliance with zero-trust security principles
 * • Enhanced audit capabilities
 * 
 * Only creates federation credentials for identities that specify 'environment'
 * in their federationTypes configuration
 */
module envFederationModules '../40-modules/core/github-federation.bicep' = [for (item, i) in items(workloadIdentities): if (contains(split(item.value.federationTypes, ','), 'environment')) {
  name: 'deploy-env-fed-${item.key}'
  scope: mgmtSharedRG
  params: {
    UamiName: uamiModules[i].outputs.uamis[0].name
    GitHubOrganizationName: gitHubOrganizationName
    GitHubRepositoryName: gitHubRepositoryName
    environmentName: item.value.ENV
    fedType: 'environment'
    federatedCredentialName: 'fc-env-${item.value.ENV}-${item.key}'
  }
  dependsOn: [uamiModules[i]]
}]


/*
 * =============================================================================
 * RBAC ROLE ASSIGNMENTS
 * =============================================================================
 * 
 * Configures role-based access control for managed identities following
 * the principle of least privilege. Each identity receives only the minimum
 * permissions required for its designated shared infrastructure operations.
 */

/*
 * SHARED HUB RESOURCE GROUP PERMISSIONS
 * Assigns configured RBAC roles to managed identities within the shared hub
 * resource group, enabling secure access to shared platform services
 * 
 * Permission Strategy:
 * • creator identity: Full Contributor access for infrastructure provisioning
 * • push identity: AcrPush access for container registry operations
 * 
 * Security Considerations:
 * • Roles scoped to specific resource group (not subscription-wide)
 * • Built-in roles used to ensure security best practices
 * • Regular access reviews recommended for compliance
 * • Principle of least privilege strictly enforced
 * • Audit logging enabled through Azure Activity Log
 */
module rbacAssignments '../40-modules/core/rbacRg.bicep' = [for (item, i) in items(workloadIdentities): {
  name: 'deploy-rbac-${item.key}'
  scope: hubRG
  params: {
    principalId: uamiModules[i].outputs.uamis[0].principalId
    roleDefinitionId: roleIdMap[item.value.ROLE]
  }
  dependsOn: [uamiModules[i]]
}]

/*
 * =============================================================================
 * TEMPLATE OUTPUTS
 * =============================================================================
 * 
 * Provides essential shared infrastructure information for consumption by
 * dependent landing zones and application deployment templates.
 */

/*
 * MANAGED IDENTITY OUTPUTS
 * Critical identity information for downstream authentication and authorization
 */
@description('Array of all created User-Assigned Managed Identity names for workload authentication')
output uamiNames array = [for (item, i) in items(workloadIdentities): uamiModules[i].outputs.uamis[0].name]

@description('Array of all User-Assigned Managed Identity principal IDs for RBAC role assignments')
output uamiPrincipalIds array = [for (item, i) in items(workloadIdentities): uamiModules[i].outputs.uamis[0].principalId]

@description('Array of federated credential configurations for GitHub Actions integration')
output federatedCredentialNames array = [for (item, i) in items(workloadIdentities): {
  env: contains(split(item.value.federationTypes, ','), 'environment') ? envFederationModules[i].outputs.federatedCredentialName : null
}]

/*
 * RESOURCE GROUP OUTPUTS
 * Foundational resource group information for dependent resource deployments
 */
@description('Management resource group name containing shared identities and access controls')
output managementResourceGroupName string = mgmtSharedRG.name

@description('Shared hub resource group name for platform services and artifacts')
output artifactsResourceGroupName string = hubRG.name
