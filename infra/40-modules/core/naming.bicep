// Naming convention module for SecureSharer
// Implements Cloud Adoption Framework naming standards
// Pattern: {proj}-{env}-{svc}-{rtype}{-seq}

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
@allowed(['ca', 'cae', 'rg', 'vnet', 'sub', 'pe', 'log', 'swa', 'kv', 'acr', 'cosmos', 'id', 'nsg', 'aks', 'agw', 'pip', 'law', 'uai'])
param resourceType string

@description('Optional sequence number (01-99)')
param sequence string = ''

// Environment mapping and name generation
var envMapping = {
  dev: 'd'
  prod: 'p'
  shared: 's'
}

var mappedEnv = envMapping[environment]
var baseName = '${projectCode}-${mappedEnv}-${serviceCode}-${resourceType}${empty(sequence) ? '' : sequence}'

// Apply sanitization rules for specific resource types
var sanitizedName = resourceType == 'kv' || resourceType == 'acr' 
  ? replace(toLower(baseName), '-', '')
  : toLower(baseName)

// Validation logic
var isValidProjectCode = length(projectCode) >= 2 && length(projectCode) <= 3
var isValidServiceCode = length(serviceCode) >= 2 && length(serviceCode) <= 4
var isValidSequence = empty(sequence) || (length(sequence) == 2 && int(sequence) >= 1 && int(sequence) <= 99)

// Outputs
output resourceName string = sanitizedName
output isValid bool = isValidProjectCode && isValidServiceCode && isValidSequence
output components object = {
  projectCode: projectCode
  environment: environment
  mappedEnvironment: mappedEnv
  serviceCode: serviceCode
  resourceType: resourceType
  sequence: sequence
  baseName: baseName
  sanitizedName: sanitizedName
}