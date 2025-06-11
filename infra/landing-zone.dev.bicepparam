// This file is used to deploy the main.bicep file in the dev environment
using 'landing-zone.bicep'

@description('Environment for the deployment')
param environmentName = 'dev'


@description('Environment name for shared resources')
param gitHubSharedEnv = 'shared'


@description('Location for the resources')
param location = 'spaincentral' // Default location, can be overridden

@description('Name of the management resource group')
param managementResourceGroupName = 'rg-ssharer-mgmt-${environmentName}'

@description('Tags for resources')
param tags = {
  Application: 'Secure Sharer'
  environment: environmentName
}

@description('GitHub organization name to federate with')
param gitHubOrganizationName = 'tiagonunes1491'

@description('GitHub repository name to federate with')
param gitHubRepositoryName = 'SecureSharer'

