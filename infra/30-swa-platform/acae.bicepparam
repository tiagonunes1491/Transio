// main.bicepparam

using 'acae.bicep'

// Basic configuration
param resourceLocation = 'spaincentral'
param projectCode = 'ss'
param serviceCode = 'swa'
param environmentName = 'dev'

// Shared infrastructure references - these should match existing resources
param sharedResourceGroupName = 'ss-s-plat-rg'

// Infrastructure resource IDs 
param logAnalyticsWorkspaceResourceId = '/subscriptions/b94fa618-3b89-4896-b727-251115f3debd/resourceGroups/ss-d-swa-rg/providers/Microsoft.OperationalInsights/workspaces/ss-d-swa-log'
param acaEnvironmentSubnetId = '/subscriptions/b94fa618-3b89-4896-b727-251115f3debd/resourceGroups/ss-d-swa-rg/providers/Microsoft.Network/virtualNetworks/ss-d-swa-vnet/subnets/snet-aca'

