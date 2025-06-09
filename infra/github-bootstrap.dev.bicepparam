// This file is used to deploy the main.bicep file in the dev environment
using 'github-bootstrap.bicep'

@description('Environment for the deployment')
param environment = 'dev'

@description('Location for the resources')
param location  = 'spaincentral'

@description('Name of the User Assigned Managed Identity (UAMI) to create')
param uamiName = 'uami-github-bootstrap-dev'

@description('GitHub organization name to federate with')
param gitHubOrganizationName = 'tiagonunes1491'

@description('GitHub repository name to federate with')
param gitHubRepositoryName = 'SecureSharer'

@description('GitHub subject pattern to federate with')
param gitHubSubjectPattern = 'refs/heads/*'

@description('Tags for resources')
param tags  = {
  purpose: 'github-actions'
  environment: environment
}
