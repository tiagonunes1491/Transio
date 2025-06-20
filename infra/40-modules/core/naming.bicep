//// filepath: c:\Users\tiagonunes\OneDrive - Microsoft\secure-secret-sharer\infra\40-modules\core\naming.bicep
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

// Environment mapping
var envMapping = {
  dev: 'd'
  prod: 'p'
  shared: 's'
}
var mappedEnv = envMapping[environment]

// Build name with optional suffix
var baseName = empty(suffix)
  ? '${projectCode}-${mappedEnv}-${serviceCode}-${resourceType}'
  : '${projectCode}-${mappedEnv}-${serviceCode}-${resourceType}-${suffix}'

// Sanitize base name for KV and ACR  
var sanitizedName = (resourceType == 'kv' || resourceType == 'acr')
  ? replace(toLower(baseName), '-', '')
  : toLower(baseName)

// Validation
var isValidSuffix = empty(suffix) || length(suffix) >= 1
var isValidProjectCode = length(projectCode) >= 2 && length(projectCode) <= 3
var isValidServiceCode = length(serviceCode) >= 2 && length(serviceCode) <= 4

// Outputs
output resourceName string = sanitizedName
output isValid bool = isValidProjectCode && isValidServiceCode && isValidSuffix
output components object = {
  projectCode: projectCode
  environment: environment
  mappedEnvironment: mappedEnv
  serviceCode: serviceCode
  resourceType: resourceType
  suffix: suffix
  baseName: baseName
  sanitizedName: sanitizedName
}
