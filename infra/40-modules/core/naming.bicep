// Module: core/naming.bicep
// Description: Standardized naming convention module for Azure resources in the Secure Secret Sharer project.
// Generates consistent, validated resource names following the pattern: {projectCode}-{env}-{serviceCode}-{resourceType}[-{suffix}]
// Handles special cases like Key Vault and Container Registry that require alphanumeric-only names.
//
// Parameters:
//   - projectCode: 2-3 character project identifier (default: 'ss')
//   - environment: Environment name (dev, prod, shared) - mapped to single character
//   - serviceCode: 2-4 character service identifier
//   - resourceType: Azure resource type code (ca, rg, kv, acr, etc.)
//   - suffix: Optional suffix for resource differentiation
//
// Environment Mapping:
//   - dev → 'd'
//   - prod → 'p' 
//   - shared → 's'
//
// Special Handling:
//   - Key Vault (kv) and Container Registry (acr): Removes hyphens for alphanumeric-only names
//   - All other resources: Maintains hyphen-separated naming
//
// Outputs:
//   - resourceName: Final sanitized resource name
//   - isValid: Boolean validation result for all input parameters
//   - components: Detailed breakdown of naming components for debugging
//
// Usage:
//   Use this module to ensure consistent naming across all Azure resources in the project.
//   Validates input parameters and provides standardized naming patterns.
//
// Example:
//   module naming 'core/naming.bicep' = {
//     name: 'resource-naming'
//     scope: subscription()
//     params: {
//       projectCode: 'ss'
//       environment: 'dev'
//       serviceCode: 'web'
//       resourceType: 'rg'
//       suffix: 'frontend'
//     }
//   }
//   // Output: ss-d-web-rg-frontend
targetScope = 'subscription'

// Input Parameters
@description('Project code (2-3 lowercase letters)')
@minLength(2)
@maxLength(3)
param projectCode string = 'ss'

@description('Environment (dev, prod, shared)')
@allowed(['dev', 'prod', 'shared'])
param environment string

@description('Service code (2-4 lowercase letters)')
@minLength(2)
@maxLength(4)
param serviceCode string

@description('Resource type code')
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

@description('Optional suffix to append (e.g. "creator", "push")')
param suffix string = ''

// Map full environment names to single-character codes for concise naming
// This reduces resource name length while maintaining readability
var envMapping = {
  dev: 'd'      // Development environment
  prod: 'p'     // Production environment
  shared: 's'   // Shared/common environment
}
var mappedEnv = envMapping[environment]

// Construct base resource name following the standardized pattern
// Pattern: {projectCode}-{env}-{serviceCode}-{resourceType}[-{suffix}]
// Suffix is only appended when provided to allow resource differentiation
var baseName = empty(suffix)
  ? '${projectCode}-${mappedEnv}-${serviceCode}-${resourceType}'
  : '${projectCode}-${mappedEnv}-${serviceCode}-${resourceType}-${suffix}'

// Apply special naming rules for Azure services with specific requirements
// Key Vault and Container Registry require alphanumeric-only names (no hyphens)
// All other resources use the standard hyphen-separated format
var sanitizedName = (resourceType == 'kv' || resourceType == 'acr')
  ? replace(toLower(baseName), '-', '')  // Remove hyphens for KV/ACR
  : toLower(baseName)                    // Standard lowercase with hyphens

// Validate input parameters to ensure they meet naming requirements
// These validations help catch configuration errors early in deployment
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
