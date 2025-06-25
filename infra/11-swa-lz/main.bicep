/*
 * =============================================================================
 * PaaS Landing Zone Infrastructure for Secure Secret Sharer
 * =============================================================================
 * 
 * This Bicep template creates the Platform-as-a-Service (PaaS) landing zone
 * infrastructure for the Secure Secret Sharer application. It establishes the
 * foundational components needed for deploying and managing PaaS workloads.
 * 
 * ARCHITECTURE OVERVIEW:
 * ┌─────────────────────────────────────────────────────────────────────────┐
 * │                       PaaS Landing Zone                                 │
 * ├─────────────────────────────────────────────────────────────────────────┤
 * │  Management RG              │  PaaS Spoke RG                            │
 * │  ┌─────────────────────┐   │  ┌─────────────────────────────────────┐  │
 * │  │ User-Assigned       │   │  │ Container Apps                      │  │
 * │  │ Managed Identities  │───┼──│ Static Web Apps                     │  │
 * │  │                     │   │  │ App Services                        │  │
 * │  │ GitHub Federation   │   │  │ Function Apps                       │  │
 * │  │ Credentials         │   │  │                                     │  │
 * │  └─────────────────────┘   │  └─────────────────────────────────────┘  │
 * └─────────────────────────────────────────────────────────────────────────┘
 * 
 * KEY FEATURES:
 * • Resource Groups: Organized separation of management and workload resources
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
 * This template operates at subscription scope to create resource groups
 * and manage subscription-level resources like managed identities.
 */
targetScope = 'subscription'

/*
 * =============================================================================
 * PARAMETER DEFINITIONS
 * =============================================================================
 * 
 * These parameters configure the deployment environment, naming conventions,
 * and security settings for the PaaS landing zone.
 */

// Environment configuration
@description('Environment for the deployment (e.g., dev, prod)')
@allowed(['dev', 'prod'])
param environmentName string = 'dev'

@description('Azure region where resources will be deployed')
param location string = 'spaincentral'

/*
 * NAMING CONVENTION PARAMETERS
 * These parameters follow the organization's naming standards:
 * Format: {projectCode}-{environment}-{serviceCode}-{resourceType}
 */
@description('Project code - identifies the project/application (e.g., ss for Secure Secret)')
param projectCode string = 'ss'

@description('Service code for SWA/ACA platform - identifies the specific service component')
param serviceCode string = 'swa'

/*
 * GOVERNANCE AND TAGGING PARAMETERS
 * These parameters support resource governance, cost management, and compliance tracking
 */
@description('Cost center for billing and chargeback purposes')
param costCenter string = '1000'

@description('Created by information - tracks who initiated the deployment')
param createdBy string = 'bicep-deployment'

@description('Owner - primary contact for the resources')
param owner string = 'tiago-nunes'

@description('Owner email - contact email for resource ownership')
param ownerEmail string = 'tiago.nunes@example.com'

@description('Creation date for tagging - automatically set to current UTC date')
param createdDate string = utcNow('yyyy-MM-dd')

/*
 * GITHUB INTEGRATION PARAMETERS
 * These parameters configure federated authentication for CI/CD pipelines
 * Enables passwordless authentication from GitHub Actions to Azure
 */
@description('GitHub organization name for federated credential setup')
param gitHubOrganizationName string

@description('GitHub repository name for federated credential setup')
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
 * Security Design:
 * • Follows zero-trust principles with environment-based federation
 * • Each identity has minimal required permissions (least privilege)
 * • Protected environments enforce additional approval workflows
 * 
 * Default Configuration:
 * • creator: Full contributor access for infrastructure provisioning
 * • push: Container registry push permissions for image publishing
 */

@description('GitHub workload identities for the shared resources infrastructure. Each entry defines a UAMI, its environment, RBAC role, and federation types.')
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
 * NAMING CONVENTION AND TAGGING CONFIGURATION
 * =============================================================================
 * 
 * This section establishes consistent naming patterns and tagging strategies
 * across all resources in the PaaS landing zone.
 */

/*
 * ENVIRONMENT MAPPING
 * Maps full environment names to abbreviated codes for consistent naming
 * This ensures resource names remain within Azure naming limits while maintaining clarity
 */
var envMapping = {
  dev: 'd'      // Development environment
  prod: 'p'     // Production environment  
  shared: 's'   // Shared/common resources
}

/*
 * RESOURCE GROUP NAMING
 * Generates consistent resource group names following organizational standards
 * Pattern: {projectCode}-{envCode}-{purpose}-rg
 * 
 * Examples:
 * - ss-s-hub-rg (Shared hub resources)
 * - ss-d-swa-rg (Development SWA resources)
 * - ss-i-mgmt-rg (Infrastructure management resources)
 */
var hubRgName = toLower('${projectCode}-${envMapping.shared}-hub-rg')      // Shared hub resource group
var paasRgName = toLower('${projectCode}-${envMapping[environmentName]}-${serviceCode}-rg')  // PaaS workload resource group
var mgmtRgName = toLower('${projectCode}-i-mgmt-rg')                       // Management resource group for identities

/*
 * STANDARDIZED TAGGING STRATEGY
 * Comprehensive tagging for governance, cost management, and operational clarity
 * These tags are applied to all resources for consistent metadata tracking
 */
var standardTags = {
  environment: environmentName        // Environment classification (dev/prod)
  project: projectCode               // Project identifier for resource grouping
  service: serviceCode               // Service component identifier
  costCenter: costCenter             // Cost allocation and chargeback
  createdBy: createdBy              // Deployment method/tool identification
  owner: owner                      // Primary resource owner
  ownerEmail: ownerEmail            // Contact information for the owner
  createdDate: createdDate          // Resource creation timestamp
  managedBy: 'bicep'                // Infrastructure as Code tool used
  deployment: deployment().name      // Specific deployment instance identifier
}

/*
 * =============================================================================
 * SECURITY AND RBAC CONFIGURATION
 * =============================================================================
 */

/*
 * AZURE BUILT-IN ROLE DEFINITIONS
 * References to Azure built-in RBAC roles for consistent permission management
 * Using built-in roles ensures security best practices and reduces maintenance overhead
 */
var ContributorRoleDefinitionId = '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'

/*
 * ROLE MAPPING FOR WORKLOAD IDENTITIES
 * Maps logical role names to Azure built-in role definition IDs
 * This abstraction allows for easy role management and consistent assignments
 */
var roleIdMap = {
  contributor: ContributorRoleDefinitionId  // Grants full access to manage resources (except access control)
}

/*
 * =============================================================================
 * EXISTING RESOURCE REFERENCES
 * =============================================================================
 * 
 * References to resources created by other landing zone components.
 * These resources must exist before this template can be deployed successfully.
 */

/*
 * SHARED HUB RESOURCE GROUP REFERENCE
 * References the hub resource group created by the shared landing zone (10-shared-lz)
 * This establishes dependency ordering and ensures proper resource organization
 */
resource hubRG 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  name: hubRgName
}

/*
 * =============================================================================
 * RESOURCE GROUP CREATION
 * =============================================================================
 * 
 * Creates the primary resource groups for organizing PaaS workloads and
 * management components following Azure landing zone principles.
 */

/*
 * PAAS SPOKE RESOURCE GROUP
 * Primary resource group for hosting PaaS workloads including:
 * - Azure Container Apps
 * - Azure Static Web Apps  
 * - Azure App Services
 * - Azure Function Apps
 * - Supporting services (Application Insights, etc.)
 */
resource paasRG 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: paasRgName
  location: location
  tags: standardTags
}

/*
 * MANAGEMENT RESOURCE GROUP
 * Dedicated resource group for identity and access management resources:
 * - User-Assigned Managed Identities (UAMIs)
 * - Federated identity credentials for GitHub
 * - Security-related configurations
 * 
 * Separating management resources provides better security boundaries
 * and follows the principle of separation of concerns.
 */
resource managementRg 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  name: mgmtRgName
}

/*
 * =============================================================================
 * MANAGED IDENTITIES AND FEDERATED CREDENTIALS
 * =============================================================================
 * 
 * This section creates secure, keyless authentication infrastructure for PaaS workloads.
 * It establishes managed identities and configures federated authentication with GitHub
 * for secure CI/CD operations without storing secrets.
 */

/*
 * NAMING MODULE FOR USER-ASSIGNED MANAGED IDENTITIES
 * Generates consistent names for UAMIs using the centralized naming module
 * This ensures all identity resources follow organizational naming standards
 * 
 * Pattern: {projectCode}-{env}-{serviceCode}-id-gh-{workloadType}
 * Example: ss-d-swa-id-gh-contributor
 */
module uamiNamingModules '../40-modules/core/naming.bicep' = [
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

/*
 * USER-ASSIGNED MANAGED IDENTITIES CREATION
 * Creates secure managed identities for each defined workload type
 * 
 * Benefits of UAMIs:
 * - No credential management required
 * - Automatic credential rotation by Azure
 * - Integration with Azure RBAC
 * - Support for federated identity scenarios
 * 
 * Each UAMI is created in the management resource group for centralized identity governance
 */
// Dynamically create UAMIs for each workload identity in the management resource group
module uamiModules '../40-modules/core//uami.bicep' = [for (item, i) in items(workloadIdentities): {
  name: 'deploy-uami-${item.key}'
  scope: managementRg
  params: {
    uamiLocation: location
    uamiNames: [uamiNamingModules[i].outputs.resourceName]
    tags: standardTags
  }
}]


/*
 * GITHUB FEDERATED IDENTITY CREDENTIALS
 * Establishes trust relationship between GitHub Actions and Azure AD
 * Enables passwordless authentication from CI/CD pipelines to Azure resources
 * 
 * Federated identity benefits:
 * - No secrets stored in GitHub repositories
 * - Automatic token lifecycle management
 * - Enhanced security through OIDC standard
 * - Fine-grained access control per environment
 * 
 * Only creates federation for workloads that specify 'environment' federation type
 */

module envFederationModules '../40-modules/core/github-federation.bicep' = [for (item, i) in items(workloadIdentities): if (contains(split(item.value.federationTypes, ','), 'environment')) {
  name: 'deploy-env-fed-${item.key}'
  scope: managementRg
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
 * 
 * Configures role-based access control (RBAC) permissions for managed identities
 * following the principle of least privilege. Each identity receives only the
 * minimum permissions required for its specific workload.
 */

/*
 * PAAS RESOURCE GROUP ROLE ASSIGNMENTS
 * Assigns the configured roles to UAMIs within the PaaS spoke resource group
 * This grants the identities permission to manage resources in their target environment
 * 
 * Security considerations:
 * - Uses principle of least privilege
 * - Role assignments scoped to specific resource group
 * - Built-in roles preferred over custom roles
 * - Regular access reviews recommended
 */
module rbacAssignments '../40-modules/core/rbacRg.bicep' = [for (item, i) in items(workloadIdentities): {
  name: 'deploy-rbac-${item.key}'
  scope: paasRG
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
 * Provides essential information for downstream deployments and integrations.
 * These outputs are consumed by application deployment templates and CI/CD pipelines.
 */

/*
 * MANAGED IDENTITY OUTPUTS
 * Essential identity information for workload authentication and authorization
 */
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

/*
 * RESOURCE GROUP OUTPUTS
 * Resource group information for resource organization and deployment targeting
 */
@description('Management resource group name containing identities and credentials')
output managementResourceGroupName string = managementRg.name

@description('Hub resource group name for shared infrastructure components')
output hubResourceGroupName string = hubRG.name

@description('PaaS resource group name for workload deployments')
output paasResourceGroupName string = paasRG.name

/*
 * AZURE ENVIRONMENT OUTPUTS
 * Subscription and tenant information for multi-tenant and cross-subscription scenarios
 */
@description('Azure AD tenant ID for identity federation configuration')
output tenantId string = subscription().tenantId

@description('Azure subscription ID for resource deployment targeting')
output subscriptionId string = subscription().subscriptionId

@description('Environment name for configuration and deployment logic')
output environmentName string = environmentName

