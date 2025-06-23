// infra/30-platform-swa-aca/main.bicep
// Single entry-point for platform: network, key vault, log analytics, PCA environment, UAMI, RBAC, plus ACA & SWA stubs

targetScope = 'resourceGroup'

@description('Azure AD tenant ID for Key Vault authentication')
param tenantId string = subscription().tenantId

@description('Deployment location')
param resourceLocation string = 'spaincentral'

@description('Project code')
param projectCode string = 'ss'

@description('Service code for SWA/ACA platform')
param serviceCode string = 'swa'

@description('Environment name')
@allowed(['dev', 'prod'])
param environmentName string = 'dev'



// ========== SHARED INFRASTRUCTURE REFERENCES ==========
@description('Existing Platform Resource Group Name')
param sharedResourceGroupName string


// ========== NAMING AND TAGGING MODULES ==========



module acaEnvNamingModule '../40-modules/core/naming.bicep' = {
  scope: subscription()
  name: 'aca-env-naming'
  params: {    
    projectCode: projectCode
    environment: environmentName
    serviceCode: serviceCode
    resourceType: 'cae'
  }
}


// ========== ACA ENVIRONMENT PARAMETERS ==========
@description('Subnet ID for the Container Apps Environment')
param acaEnvironmentSubnetId string = '/subscriptions/b94fa618-3b89-4896-b727-251115f3debd/resourceGroups/ss-d-swa-rg/providers/Microsoft.Network/virtualNetworks/ss-d-swa-vnet/subnets/snet-aca'

@description('Log Analytics Workspace Resource ID for Container Apps Environment monitoring')
param logAnalyticsWorkspaceResourceId string = '/subscriptions/b94fa618-3b89-4896-b727-251115f3debd/resourceGroups/ss-d-swa-rg/providers/Microsoft.OperationalInsights/workspaces/ss-d-swa-log'

// ========== ACA ENVIRONMENT ==========
module acaEnv '../40-modules/core/aca-environment.bicep' = {
  name:  'acaEnvironment'
  params: {
    acaEnvironmentName: acaEnvNamingModule.outputs.resourceName
    acaEnvironmentLocation: resourceLocation
    workspaceId: logAnalyticsWorkspaceResourceId
    acaEnvironmentSubnetId: acaEnvironmentSubnetId
  }
}
