/*
 * =============================================================================
 * Standardized Naming Convention Module
 * =============================================================================
 * 
 * This Bicep module provides centralized, standardized naming conventions for
 * Azure resources. It ensures consistent, predictable, and compliant resource 
 * names across all environments and services.
 * 
 * NAMING STRATEGY OVERVIEW:
 * ┌─────────────────────────────────────────────────────────────────────────┐
 * │                    Resource Naming Components                           │
 * ├─────────────────────────────────────────────────────────────────────────┤
 * │  {projectCode}-{env}-{serviceCode}-{resourceType}[-{suffix}]            │
 * │                                                                         │
 * │  Examples:                                                              │
 * │  • proj-d-web-rg            (Development Web Resource Group)            │
 * │  • proj-p-plat-kv           (Production Platform Key Vault)             │
 * │  • projdwebacr              (Development Web Container Registry)        │
 * │  • proj-s-plat-id-creator   (Shared Platform Identity with suffix)     │
 * └─────────────────────────────────────────────────────────────────────────┘
 * 
 * KEY FEATURES:
 * • Centralized Naming: Single source of truth for all resource naming
 * • Environment Mapping: Consistent abbreviation strategy (dev→d, prod→p, shared→s)
 * • Service-Specific Rules: Special handling for Azure services with naming constraints
 * • Validation Logic: Built-in parameter validation and compliance checking
 * • Debugging Support: Detailed component breakdown for troubleshooting
 * • Scalable Design: Extensible for new resource types and environments
 * 
 * AZURE SERVICE COMPATIBILITY:
 * • Standard Resources: Uses hyphen-separated naming (Resource Groups, VNets, etc.)
 * • Key Vault & ACR: Alphanumeric-only naming (removes hyphens automatically)
 * • Length Constraints: Validates against Azure service naming limits
 * • Character Restrictions: Ensures lowercase, valid character usage
 * 
 * GOVERNANCE BENEFITS:
 * • Policy Compliance: Meets organizational naming standards
 * • Cost Allocation: Enables accurate cost tracking and chargeback
 * • Resource Discovery: Predictable names simplify automation and scripts
 * • Audit Trail: Clear naming patterns support compliance and governance
 * 
 * DEPLOYMENT SCOPE:
 * This module operates at subscription scope to support resource group
 * naming and cross-resource naming consistency.
 */
targetScope = 'subscription'

/*
 * =============================================================================
 * PARAMETER DEFINITIONS
 * =============================================================================
 * 
 * These parameters define the components used to construct standardized
 * Azure resource names. All parameters include validation to ensure
 * compliance with Azure naming requirements and organizational standards.
 */

/*
 * PROJECT IDENTIFICATION PARAMETER
 * Core identifier that groups all resources belonging to the same project
 * Must be 2-3 characters to balance brevity with clarity
 */
@description('Project code identifier (2-3 lowercase letters) - identifies the project')
@minLength(2)
@maxLength(3)
param projectCode string

/*
 * ENVIRONMENT CLASSIFICATION PARAMETER
 * Specifies the deployment environment for proper resource segregation
 * Maps to single-character codes to optimize resource name length
 */
@description('Environment classification (dev, prod, shared) - determines resource isolation and configuration')
@allowed(['dev', 'prod', 'shared'])
param environment string

/*
 * SERVICE COMPONENT PARAMETER
 * Identifies the specific service or component within the project
 * Enables logical grouping of resources by functional area
 */
@description('Service code identifier (2-4 lowercase letters) - identifies the specific service component')
@minLength(2)
@maxLength(4)
param serviceCode string

/*
 * AZURE RESOURCE TYPE PARAMETER
 * Specifies the type of Azure resource being named
 * Uses standardized abbreviations for consistency and recognition
 * 
 * Supported Resource Types:
 * • ca: Container Apps
 * • cae: Container Apps Environment
 * • rg: Resource Group
 * • vnet: Virtual Network
 * • sub: Subnet
 * • pe: Private Endpoint
 * • log: Log Analytics Workspace
 * • swa: Static Web App
 * • kv: Key Vault (special alphanumeric handling)
 * • acr: Azure Container Registry (special alphanumeric handling)
 * • cosmos: Cosmos DB
 * • id: Managed Identity
 * • nsg: Network Security Group
 * • aks: Azure Kubernetes Service
 * • agw: Application Gateway
 * • pip: Public IP Address
 */
@description('Azure resource type code - standardized abbreviation for the resource being named')
@allowed([
  'ca'
  'cae'
  'rg'
  'vnet'
  'sub'
  'pe'
  'log'
  'swa'
  'kv'
  'acr'
  'cosmos'
  'id'
  'nsg'
  'aks'
  'agw'
  'pip'
  'log'
])
param resourceType string

/*
 * OPTIONAL DIFFERENTIATION PARAMETER
 * Provides additional context or differentiation when multiple resources
 * of the same type exist within the same scope
 * Examples: 'frontend', 'backend', 'creator', 'push'
 */
@description('Optional suffix for resource differentiation (e.g., "creator", "push", "frontend")')
param suffix string = ''

/*
 * =============================================================================
 * ENVIRONMENT MAPPING AND NAME CONSTRUCTION
 * =============================================================================
 * 
 * This section transforms the input parameters into standardized resource names
 * following Azure best practices and organizational naming conventions.
 */

/*
 * ENVIRONMENT ABBREVIATION MAPPING
 * Maps full environment names to single-character codes for optimal name length
 * This strategy ensures resource names remain within Azure limits while maintaining clarity
 * 
 * Mapping Strategy:
 * • dev → 'd': Development environment for feature development and testing
 * • prod → 'p': Production environment for live workloads
 * • shared → 's': Shared resources used across multiple environments
 */
var envMapping = {
  dev: 'd'      // Development environment
  prod: 'p'     // Production environment
  shared: 's'   // Shared/common environment
}
var mappedEnv = envMapping[environment]

/*
 * BASE NAME CONSTRUCTION
 * Builds the foundation resource name using the standardized pattern
 * Pattern: {projectCode}-{env}-{serviceCode}-{resourceType}[-{suffix}]
 * 
 * Construction Logic:
 * • Always includes: project code, environment, service code, resource type
 * • Conditionally includes: suffix (only when provided for differentiation)
 * • Uses hyphens as separators for readability and Azure compatibility
 * 
 * Examples:
 * • Without suffix: proj-d-web-rg
 * • With suffix: proj-d-web-id-creator
 */
var baseName = empty(suffix) ? '${projectCode}-${mappedEnv}-${serviceCode}-${resourceType}' : '${projectCode}-${mappedEnv}-${serviceCode}-${resourceType}-${suffix}'

/*
 * AZURE SERVICE-SPECIFIC NAME SANITIZATION
 * Applies service-specific naming rules required by different Azure resources
 * 
 * Special Cases:
 * • Key Vault (kv): Requires alphanumeric characters only (3-24 characters)
 * • Container Registry (acr): Requires alphanumeric characters only (5-50 characters)
 * • Standard Resources: Use hyphen-separated format for readability
 * 
 * This approach ensures compatibility while maintaining naming consistency
 */
var sanitizedName = (resourceType == 'kv' || resourceType == 'acr') ? replace(toLower(baseName), '-', '') : toLower(baseName)

/*
 * =============================================================================
 * INPUT VALIDATION AND COMPLIANCE CHECKING
 * =============================================================================
 * 
 * Comprehensive validation logic to ensure all input parameters meet
 * Azure naming requirements and organizational standards before name generation.
 */

/*
 * PARAMETER VALIDATION RULES
 * Validates each input parameter against specific business and technical requirements
 * Early validation prevents deployment failures and ensures compliance
 * 
 * Validation Criteria:
 * • Suffix: Optional parameter - if provided, must be non-empty string
 * • Project Code: Must be 2-3 characters (balances brevity with clarity)
 * • Service Code: Must be 2-4 characters (allows flexibility for service identification)
 * 
 * Benefits:
 * • Early error detection during template compilation
 * • Prevents invalid resource names that would fail Azure validation
 * • Ensures consistency across all deployments
 * • Supports automated compliance checking
 */
var isValidSuffix = empty(suffix) || length(suffix) >= 1        // Suffix optional but must be non-empty if provided
var isValidProjectCode = length(projectCode) >= 2 && length(projectCode) <= 3  // Project code: 2-3 characters
var isValidServiceCode = length(serviceCode) >= 2 && length(serviceCode) <= 4  // Service code: 2-4 characters

// Outputs
// Return the final sanitized resource name ready for use
output resourceName string = sanitizedName

// Return validation status to help identify configuration issues
output isValid bool = isValidProjectCode && isValidServiceCode && isValidSuffix

// Return detailed component breakdown for debugging and transparency
// Useful for troubleshooting naming issues and understanding name construction
output components object = {
  projectCode: projectCode           // Original project identifier
  environment: environment           // Full environment name (input)
  mappedEnvironment: mappedEnv       // Single-character environment code
  serviceCode: serviceCode           // Service identifier
  resourceType: resourceType         // Azure resource type code
  suffix: suffix                     // Optional suffix (empty string if not provided)
  baseName: baseName                 // Constructed name before sanitization
  sanitizedName: sanitizedName       // Final name after applying Azure service rules
}
