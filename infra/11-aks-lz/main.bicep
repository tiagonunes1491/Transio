/*
 * =============================================================================
 * Kubernetes Landing Zone Infrastructure for Secure Secret Sharer
 * =============================================================================
 * 
 * This Bicep template creates the Kubernetes (AKS) landing zone infrastructure
 * for the Secure Secret Sharer application. It establishes the foundational
 * components needed for deploying and managing containerized workloads on
 * Azure Kubernetes Service with secure, scalable, and well-governed identity management.
 * 
 * ARCHITECTURE OVERVIEW:
 * ┌─────────────────────────────────────────────────────────────────────────┐
 * │                       AKS Landing Zone                                  │
 * ├─────────────────────────────────────────────────────────────────────────┤
 * │  Management RG              │  AKS Spoke RG                             │
 * │  ┌─────────────────────┐   │  ┌─────────────────────────────────────┐  │
 * │  │ User-Assigned       │   │  │ Kubernetes Cluster                  │  │
 * │  │ Managed Identities  │───┼──│ Node Pools                          │  │
 * │  │                     │   │  │ Networking Components               │  │
 * │  │ GitHub Federation   │   │  │ Storage Classes                     │  │
 * │  │ Credentials         │   │  │ Application Gateways                │  │
 * │  │                     │   │  │ Load Balancers                      │  │
 * │  │ RBAC Assignments    │   │  │ Security Policies                   │  │
 * │  └─────────────────────┘   │  └─────────────────────────────────────┘  │
 * └─────────────────────────────────────────────────────────────────────────┘
 * 
 * KEY FEATURES:
 * • Resource Groups: Organized separation of management and workload resources
 * • Managed Identities: Secure, keyless authentication for Kubernetes services
 * • GitHub Federation: Passwordless CI/CD authentication from GitHub Actions
 * • RBAC Integration: Fine-grained access control for cluster and container operations
 * • Container Registry Access: Secure image pull capabilities for AKS workloads
 * • Naming Convention: Consistent, predictable resource naming across environments
 * • Comprehensive Tagging: Full metadata strategy for governance and cost tracking
 * 
 * SECURITY CONSIDERATIONS:
 * • Uses managed identities to eliminate credential management complexity
 * • Implements federated identity for secure CI/CD without stored secrets
 * • Applies minimal RBAC permissions based on specific workload requirements
 * • Separates cluster management from container registry operations
 * • Follows Azure Well-Architected security pillar guidelines
 * • Built-in audit trails through comprehensive tagging and deployment tracking
 * 
 * DEPLOYMENT SCOPE:
 * This template operates at subscription scope to create foundational
 * resource groups and manage cross-resource group identity assignments
 * required for Kubernetes workload deployment and management.
 */
targetScope = 'subscription'

/*
 * =============================================================================
 * PARAMETER DEFINITIONS
 * =============================================================================
 * 
 * These parameters configure the AKS landing zone deployment, establishing
 * environment-specific settings, identity configurations, and security
 * policies that will be inherited by Kubernetes workload deployments.
 */

/*
 * INFRASTRUCTURE CONFIGURATION PARAMETERS
 * Core settings that define the deployment environment and organizational structure
 */
@description('Environment for the deployment - determines resource naming and configuration scope')
@allowed(['dev', 'prod'])
param environmentName string = 'dev'

@description('Azure region where AKS landing zone resources will be deployed')
param location string = 'spaincentral'

/*
 * ORGANIZATIONAL NAMING PARAMETERS
 * These parameters establish the naming hierarchy for all resources:
 * Pattern: {projectCode}-{environment}-{serviceCode}-{resourceType}
 */
@description('Project code - root identifier for the Secure Secret Sharer project')
param projectCode string = 'ss'

@description('Service code for Kubernetes platform - identifies AKS infrastructure components')
param serviceCode string = 'aks'

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
 * Defines the managed identities required for different AKS operations
 * Each identity is configured with specific roles and federation capabilities
 * 
 * Structure Explanation:
 * - Key: Logical identifier for the workload type (e.g., 'k8s', 'k8sDeploy')
 * - ENV: GitHub environment name for federation scope
 * - ROLE: Azure RBAC role to assign (maps to built-in role definitions)
 * - federationTypes: Authentication methods supported (comma-separated)
 * 
 * Security Design:
 * • Follows zero-trust principles with environment-based federation
 * • Each identity has minimal required permissions (least privilege)
 * • Separation between cluster management and image pull operations
 * 
 * Default Configuration:
 * • k8s: Full contributor access for cluster and resource management
 * • k8sDeploy: Container registry pull permissions for image deployment
 */
@description('AKS workload identities configuration with environment-specific roles and federation settings')
/*
 * =============================================================================
 * NAMING CONVENTION AND TAGGING STRATEGY
 * =============================================================================
 * 
 * Establishes consistent naming patterns and comprehensive tagging for all
 * AKS landing zone resources, ensuring governance and operational clarity.
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
 * RESOURCE GROUP NAMING VARIABLES
 * Direct naming for resource groups that need to be available at compile time
 * Follows the pattern: {projectCode}-{envCode}-{serviceCode}-{resourceType}
 * 
 * Examples:
 * - ss-d-aks-rg (Development AKS resource group)
 * - ss-s-hub-rg (Shared hub resource group)
 * - ss-i-mgmt-rg (Infrastructure management resource group)
 */
var hubRgName = toLower('${projectCode}-${envMapping.shared}-hub-rg')           // Shared hub for platform services
var k8sRgName = toLower('${projectCode}-${envMapping[environmentName]}-${serviceCode}-rg')  // AKS workload resource group
var mgmtRgName = toLower('${projectCode}-i-mgmt-rg')                           // Management layer for identities

/*
 * COMPREHENSIVE TAGGING STRATEGY
 * Standardized tags applied to all resources for governance, cost allocation,
 * and operational management. These tags support automated policies and reporting.
 */
var standardTags = {
  environment: environmentName             // Environment classification for AKS resources
  project: projectCode                     // Project identifier for resource grouping
  service: serviceCode                     // Service component for logical organization
  costCenter: costCenter                   // Financial allocation and chargeback tracking
  createdBy: createdBy                    // Provisioning method for audit trails
  owner: owner                            // Accountability and primary contact
  ownerEmail: ownerEmail                  // Operational contact information
  createdDate: createdDate                // Resource lifecycle tracking
  managedBy: 'bicep'                      // Infrastructure as Code tool identification
  deployment: deployment().name            // Specific deployment instance for troubleshooting
}

/*
 * =============================================================================
 * AZURE RBAC ROLE DEFINITIONS
 * =============================================================================
 * 
 * Maps logical role names to Azure built-in role definition IDs for consistent
 * and secure permission management across all AKS workload identities.
 * 
 * SECURITY NOTE: Using built-in roles follows least privilege principle and
 * ensures Microsoft-maintained security best practices are applied.
 */

/*
 * ROLE DEFINITION MAPPING
 * Centralized mapping of workload roles to Azure built-in role definitions
 * Using built-in roles ensures security best practices and reduces maintenance overhead
 * 
 * Role Descriptions:
 * • Contributor: Full management access to resources (excludes access management)
 * • AcrPull: Azure Container Registry pull permissions for image deployment
 * 
 * IMPORTANT: Role IDs are subscription-scoped for compatibility with Azure RBAC.
 * These GUIDs are Microsoft-defined constants that remain stable across tenants.
 */
var AcrPullRoleDefinitionId = '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/7f951dda-4ed3-4680-a7ca-43fe172d538d'     // Built-in AcrPull role
var ContributorRoleDefinitionId = '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c' // Built-in Contributor role

/*
 * ROLE MAPPING FOR WORKLOAD IDENTITIES
 * Maps logical role names to subscription-scoped role definition IDs
 * Enables consistent role assignment across all managed identities
 */
var roleIdMap = {
  contributor: ContributorRoleDefinitionId  // Full resource management access
  AcrPull: AcrPullRoleDefinitionId         // Container registry pull-only access
}

/*
 * =============================================================================
 * FOUNDATIONAL RESOURCE GROUPS
 * =============================================================================
 * 
 * Creates and references the core resource groups that form the foundation
 * of the AKS landing zone, organizing resources by function and security requirements.
 */

/*
 * EXISTING SHARED HUB RESOURCE GROUP REFERENCE
 * References the shared hub resource group created by the shared landing zone
 * This resource group contains shared platform services like ACR and Key Vault
 */
resource hubRG 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  name: hubRgName
}

/*
 * AKS SPOKE RESOURCE GROUP
 * Dedicated resource group for AKS cluster and all related Kubernetes resources
 * 
 * Typical contents:
 * • Azure Kubernetes Service (AKS) cluster
 * • Node pools and virtual machine scale sets
 * • Load balancers and network security groups
 * • Application gateways and ingress controllers
 * • Persistent volume storage resources
 * • Kubernetes-specific monitoring and logging components
 */
resource k8sRG 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: k8sRgName
  location: location
  tags: standardTags
}

/*
 * MANAGEMENT RESOURCE GROUP
 * Dedicated resource group for identity and access management components
 * that require special security considerations and governance
 * 
 * Contains:
 * • User-Assigned Managed Identities (UAMIs) for AKS workloads
 * • Federated identity credentials for GitHub integration
 * • Cross-subscription identity resources (if needed)
 * 
 * Security rationale:
 * Separating identity resources provides better security boundaries,
 * enables specialized access controls, and follows defense-in-depth principles
 */
resource managementRg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: mgmtRgName
  location: location
  tags: standardTags
}

/*
 * =============================================================================
 * MANAGED IDENTITIES AND FEDERATED AUTHENTICATION
 * =============================================================================
 * 
 * Establishes secure, keyless authentication infrastructure for AKS operations.
 * Creates managed identities and configures GitHub federation for secure CI/CD
 * without credential storage.
 */

/*
 * MANAGED IDENTITY NAMING GENERATION
 * Uses centralized naming module to generate consistent names for all UAMIs
 * Ensures compliance with organizational naming standards and policies
 * 
 * Naming Pattern: {projectCode}-{environment}-{serviceCode}-{resourceType}-gh-{workloadType}
 * Examples: ss-d-aks-id-gh-k8s, ss-d-aks-id-gh-k8sDeploy
 */
module uamiNamingK8s '../40-modules/core/naming.bicep' = {
  name: 'uami-naming-k8s'
  scope: subscription()
  params: {
    projectCode: projectCode
    environment: environmentName
    serviceCode: serviceCode
    resourceType: 'id'
    suffix: 'gh-k8s'
  }
}

module uamiNamingK8sDeploy '../40-modules/core/naming.bicep' = {
  name: 'uami-naming-k8sDeploy'
  scope: subscription()
  params: {
    projectCode: projectCode
    environment: environmentName
    serviceCode: serviceCode
    resourceType: 'id'
    suffix: 'gh-k8sDeploy'
  }
}

/*
 * USER-ASSIGNED MANAGED IDENTITIES CREATION
 * Creates secure managed identities for each defined AKS workload operation type
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
module uamiK8s '../40-modules/core/uami.bicep' = {
  name: 'deploy-uami-k8s'
  scope: managementRg
  params: {
    uamiLocation: location
    uamiNames: [uamiNamingK8s.outputs.resourceName]
    tags: standardTags
  }
}

module uamiK8sDeploy '../40-modules/core/uami.bicep' = {
  name: 'deploy-uami-k8sDeploy'
  scope: managementRg
  params: {
    uamiLocation: location
    uamiNames: [uamiNamingK8sDeploy.outputs.resourceName]
    tags: standardTags
  }
}

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
 * IMPORTANT: Only creates federation credentials for identities that specify 
 * 'environment' in their federationTypes configuration. This conditional
 * approach supports flexible authentication patterns while maintaining security.
 */
module envFederationK8s '../40-modules/core/github-federation.bicep' = {
  name: 'deploy-env-fed-k8s'
  scope: managementRg
  params: {
    UamiName: uamiK8s.outputs.uamis[0].name
    GitHubOrganizationName: gitHubOrganizationName
    GitHubRepositoryName: gitHubRepositoryName
    environmentName: environmentName
    fedType: 'environment'
    federatedCredentialName: 'fc-env-${environmentName}-k8s'
  }
}

module envFederationK8sDeploy '../40-modules/core/github-federation.bicep' = {
  name: 'deploy-env-fed-k8sDeploy'
  scope: managementRg
  params: {
    UamiName: uamiK8sDeploy.outputs.uamis[0].name
    GitHubOrganizationName: gitHubOrganizationName
    GitHubRepositoryName: gitHubRepositoryName
    environmentName: environmentName
    fedType: 'environment'
    federatedCredentialName: 'fc-env-${environmentName}-k8sDeploy'
  }
}

/*
 * =============================================================================
 * RBAC ROLE ASSIGNMENTS
 * =============================================================================
 * 
 * Configures role-based access control for managed identities following
 * the principle of least privilege. Each identity receives only the minimum
 * permissions required for its designated AKS operations.
 */

/*
 * AKS SPOKE RESOURCE GROUP PERMISSIONS
 * Assigns configured RBAC roles to managed identities within the AKS spoke
 * resource group, enabling secure access to Kubernetes resources
 * 
 * Permission Strategy:
 * • k8s identity: Full Contributor access for cluster management and resource provisioning
 * • k8sDeploy identity: AcrPull access for container image deployment operations
 * 
 * Security Considerations:
 * • Roles scoped to specific resource group (not subscription-wide)
 * • Built-in roles used to ensure security best practices
 * • Regular access reviews recommended for compliance
 * • Principle of least privilege strictly enforced
 * • Audit logging enabled through Azure Activity Log
 */
module rbacK8s '../40-modules/core/rbacRg.bicep' = {
  name: 'deploy-rbac-k8s'
  scope: k8sRG
  params: {
    principalId: uamiK8s.outputs.uamis[0].principalId
    roleDefinitionId: roleIdMap.contributor
  }
}

module rbacK8sDeploy '../40-modules/core/rbacRg.bicep' = {
  name: 'deploy-rbac-k8sDeploy'
  scope: k8sRG
  params: {
    principalId: uamiK8sDeploy.outputs.uamis[0].principalId
    roleDefinitionId: roleIdMap.AcrPull
  }
}

/*
 * =============================================================================
 * TEMPLATE OUTPUTS
 * =============================================================================
 * 
 * Provides essential AKS landing zone information for consumption by
 * dependent Kubernetes deployment templates and application workloads.
 */

/*
 * MANAGED IDENTITY OUTPUTS
 * Critical identity information for downstream authentication and authorization.
 * These outputs enable dependent templates to reference AKS identities securely.
 */
@description('Array of all created User-Assigned Managed Identity names for AKS workload authentication')
output uamiNames array = [
  uamiK8s.outputs.uamis[0].name
  uamiK8sDeploy.outputs.uamis[0].name
]

@description('Array of all User-Assigned Managed Identity principal IDs for RBAC role assignments')
output uamiPrincipalIds array = [
  uamiK8s.outputs.uamis[0].principalId
  uamiK8sDeploy.outputs.uamis[0].principalId
]

@description('Array of federated credential configurations for GitHub Actions integration')
output federatedCredentialNames array = [
  {
    env: envFederationK8s.outputs.federatedCredentialName
  }
  {
    env: envFederationK8sDeploy.outputs.federatedCredentialName
  }
]

/*
 * RESOURCE GROUP OUTPUTS
 * Foundational resource group information for dependent resource deployments
 */
@description('Management resource group name containing AKS identities and access controls')
output managementResourceGroupName string = managementRg.name

@description('Shared hub resource group name for platform services and artifacts')
output hubResourceGroupName string = hubRG.name

@description('AKS spoke resource group name for Kubernetes cluster and workload resources')
output k8sResourceGroupName string = k8sRG.name

/*
 * ENVIRONMENT CONTEXT OUTPUTS
 * Essential deployment context information for dependent templates
 */
@description('Azure Active Directory tenant ID for identity and authentication context')
output tenantId string = subscription().tenantId

@description('Azure subscription ID for resource deployment and management context')
output subscriptionId string = subscription().subscriptionId

@description('Environment name for configuration and deployment targeting')
output environmentName string = environmentName
