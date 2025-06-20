// Standardized tagging module for SecureSharer
// Implements Cloud Adoption Framework tagging standards

targetScope = 'subscription'

// Input Parameters
@description('Environment name')
@allowed(['dev', 'prod', 'shared'])
param environment string

@description('Project code (2-3 lowercase letters)')
@minLength(2)
@maxLength(3)
param project string

@description('Service code (2-4 lowercase letters)')
@minLength(2)
@maxLength(4)
param service string

@description('Cost center (4-6 digits)')
@minLength(4)
@maxLength(6)
param costCenter string

@description('Created by (letters, numbers, spaces, underscore, dash)')
param createdBy string

@description('Owner (lowercase letters, numbers, dash)')
param owner string

@description('Owner email address')
param ownerEmail string

@description('Additional tags to merge')
param additionalTags object = {}

@description('Optional deployment name for traceability')
param deploymentName string = deployment().name

@description('Creation date for tagging')
param createdDate string = utcNow('yyyy-MM-dd')

// Standard tag generation
var standardTags = {
  environment: environment
  project: project
  service: service
  costCenter: costCenter
  createdBy: createdBy
  owner: owner
  ownerEmail: ownerEmail
  createdDate: createdDate
  managedBy: 'bicep'
  deployment: deploymentName
}

var allTags = union(standardTags, additionalTags)

// Validation logic
var isValidProject = length(project) >= 2 && length(project) <= 3
var isValidService = length(service) >= 2 && length(service) <= 4
var isValidCostCenter = length(costCenter) >= 4 && length(costCenter) <= 6
var isValidCreatedBy = length(createdBy) > 0
var isValidOwner = length(owner) > 0
var isValidEmail = contains(ownerEmail, '@') && contains(ownerEmail, '.')
var isValid = isValidProject && isValidService && isValidCostCenter && isValidCreatedBy && isValidOwner && isValidEmail

// Outputs
output tags object = allTags
output isValid bool = isValid
output validation object = {
  project: {
    value: project
    isValid: isValidProject
  }
  service: {
    value: service
    isValid: isValidService
  }
  costCenter: {
    value: costCenter
    isValid: isValidCostCenter
  }
  createdBy: {
    value: createdBy
    isValid: isValidCreatedBy
  }
  owner: {
    value: owner
    isValid: isValidOwner
  }
  ownerEmail: {
    value: ownerEmail
    isValid: isValidEmail
  }
}