/*
 * =============================================================================
 * AKS Cluster Module
 * =============================================================================
 *
 * This Bicep module creates and configures an Azure Kubernetes Service (AKS) cluster.
 * It is designed to be modular and reusable, supporting enterprise-grade Kubernetes infrastructure
 * with system and user node pools, security hardening, and comprehensive monitoring capabilities.
 *
 * Suitable for a wide range of workloads and environments.
 */

@description('Location of the AKS cluster')
param location string

@description('Name of the AKS cluster')
param aksName string

@description('DNS prefix for the AKS cluster')
param dnsPrefix string = uniqueString(resourceGroup().id, aksName)

@description('Kubernetes version for the AKS cluster. Best practice: allow override, but default to a stable, tested version. If a future version introduces breaking changes, freeze this value or create a new module revision.')
param kubernetesVersion string = '1.31.7'

@description('System node pool name for the AKS cluster')
param systemNodePoolName string = 'systempool'

@description('System node pool VM size for the AKS cluster')
param systemNodePoolVmSize string = 'Standard_DS2_v2'

@description('System node pool minimum number of nodes for the AKS cluster')
param systemNodePoolMinCount int = 1

@description('System node pool maximum number of nodes for the AKS cluster')
param systemNodePoolMaxCount int = 3

@description('User node pool name for the AKS cluster')
param userNodePoolName string = 'userpool'

@description('User node pool VM size for the AKS cluster')
param userNodePoolVmSize string = 'Standard_DS2_v2'

@description('User node pool OS type for the AKS cluster')
param userNodePoolOsType string = 'Linux'

@description('User node pool minimum number of nodes for the AKS cluster')
param userNodePoolMinCount int = 1

@description('User node pool maximum number of nodes for the AKS cluster')
param userNodePoolMaxCount int = 3

@description('AKS subnet ID for the AKS cluster')
param aksSubnetId string

@description('AKS Admin group object IDs for the AKS cluster')
param aksAdminGroupObjectIds array = []

@description('Tags for the AKS cluster')
param tags object = {}

@description('Application Gateeway ID for AGIC integration')
param applicationGatewayIdForAgic string = ''

@description('Enable workload identity for the AKS cluster')
param enableWorkloadIdentity bool = true

@description('The type of managed identity to use for the AKS cluster')
@allowed([
  'SystemAssigned'
  'UserAssigned'
])
param identityType string = 'SystemAssigned'

@description('User assigned identity resource IDs (required when using UserAssigned identity type)')
param userAssignedIdentities array = []

@description('Enable Azure Active Directory integration for the AKS cluster')
param enableAadIntegration bool = true

@description('Enable Azure RBAC for the Kubernetes API (requires AAD integration)')
param enableAzureRbac bool = false

@description('Enable Kubernetes RBAC')
param enableKubeRbac bool = true

@description('Disable local accounts for the AKS API server')
param disableLocalAccounts bool = true

@description('Enable OIDC issuer profile for the AKS cluster')
param enableOidcIssuerProfile bool = true

@description('Network plugin for AKS cluster')
@allowed([
  'azure'
  'kubenet'
])
param networkPlugin string = 'azure'

@description('Network plugin mode for AKS cluster')
@allowed([
  'overlay'
  'transparent'
])
param networkPluginMode string = 'overlay'

@description('Network policy for AKS cluster')
@allowed([
  'azure'
  'calico'
  'none'
])
param networkPolicy string = 'azure'

@description('Load Balancer SKU for the AKS cluster')
@allowed([
  'Standard'
  'Basic'
])
param loadBalancerSku string = 'Standard'

@description('Service CIDR for the AKS cluster')
param serviceCidr string = '10.1.0.0/16'

@description('DNS service IP for the AKS cluster')
param dnsServiceIP string = '10.1.0.10'

@description('Whether to deploy a user node pool')
param createUserNodePool bool = true

@description('Enable Azure Key Vault Secrets Provider addon')
param enableKeyVaultSecretsProvider bool = true

@description('Enable secret rotation for the Key Vault Secrets Provider addon')
param enableKeyVaultSecretRotation bool = false

@description('Watch namespace for the Ingress Application Gateway addon')
param agicWatchNamespace string = 'default'

@description('Enable private cluster (restrict API server to private network)')
param enablePrivateCluster bool = false

@description('Log Analytics Workspace resource ID for Azure Monitor integration')
param logAnalyticsWorkspaceResourceId string = ''

// Consolidated diagnostic settings object: specify logs and metrics with full configuration
@description('Diagnostic settings configuration for Azure Monitor integration')
param diagnosticSettings object = {
  logs: [
    {
      category: 'kube-apiserver'
      enabled: true
      retentionPolicy: {
        enabled: false
        days: 0
      }
    }
    {
      category: 'kube-controller-manager'
      enabled: true
      retentionPolicy: {
        enabled: false
        days: 0
      }
    }
    {
      category: 'kube-scheduler'
      enabled: true
      retentionPolicy: {
        enabled: false
        days: 0
      }
    }
    {
      category: 'kube-audit'
      enabled: true
      retentionPolicy: {
        enabled: false
        days: 0
      }
    }
  ]
  metrics: [
    {
      category: 'AllMetrics'
      enabled: true
      retentionPolicy: {
        enabled: false
        days: 0
      }
    }
  ]
}
@description('User-assigned managed identity resource ID for AGIC (optional)')
param agicUserAssignedIdentityId string = ''

@description('User-assigned managed identity resource ID for kubelet identity (optional)')
param kubeletUserAssignedIdentityId string = ''

var userAssignedIdentitiesObject = toObject(userAssignedIdentities, id => id, id => {})

resource aks 'Microsoft.ContainerService/managedClusters@2025-02-01' = {
  tags: tags
  name: aksName
  location: location
  identity: {
    type: identityType
    ...(identityType == 'UserAssigned' ? {
      userAssignedIdentities: userAssignedIdentitiesObject
    } : {})
  }
  properties: {
    disableLocalAccounts: disableLocalAccounts
    enableRBAC: enableKubeRbac
    ...(enableAadIntegration ? {
      aadProfile: {
        managed: true
        enableAzureRBAC: enableAzureRbac
        adminGroupObjectIDs: aksAdminGroupObjectIds
      }
    } : {})
    ...(enableOidcIssuerProfile ? {
      oidcIssuerProfile: {
        enabled: true
      }
    } : {})
    servicePrincipalProfile: {
      clientId: 'msi'
    }
    ...((!empty(kubeletUserAssignedIdentityId)) ? {
      identityProfile: {
        kubeletidentity: {
          resourceId: kubeletUserAssignedIdentityId
        }
      }
    } : {})
    securityProfile: {
      workloadIdentity: {
        enabled: enableWorkloadIdentity
      }
    }
    agentPoolProfiles: [
      {
        name: systemNodePoolName
        mode: 'System'
        vmSize: systemNodePoolVmSize
        enableAutoScaling: true
        minCount: systemNodePoolMinCount
        maxCount: systemNodePoolMaxCount
        osType: 'Linux'
        vnetSubnetID: aksSubnetId
        type: 'VirtualMachineScaleSets'
      }
      ...(createUserNodePool ? [
        {
          name: userNodePoolName
          mode: 'User'
          vmSize: userNodePoolVmSize
          enableAutoScaling: true
          minCount: userNodePoolMinCount
          maxCount: userNodePoolMaxCount
          osType: userNodePoolOsType
          vnetSubnetID: aksSubnetId
          type: 'VirtualMachineScaleSets'
        }
      ] : [])
    ]
    dnsPrefix: dnsPrefix
    kubernetesVersion: kubernetesVersion
    networkProfile: {
      networkPlugin: networkPlugin
      networkPluginMode: networkPluginMode
      networkPolicy: networkPolicy
      loadBalancerSku: loadBalancerSku
      serviceCidr: serviceCidr
      dnsServiceIP: dnsServiceIP
    }
    addonProfiles: {
      ...(enableKeyVaultSecretsProvider ? {
        azureKeyvaultSecretsProvider: {
          enabled: true
          config: {
            enableSecretRotation: string(enableKeyVaultSecretRotation)
          }
        }
      } : {})
      ...( !empty(applicationGatewayIdForAgic) ? {
        ingressApplicationGateway: {
          enabled: true
          config: {
            applicationGatewayId: applicationGatewayIdForAgic
            watchNamespace: agicWatchNamespace
            ...(!empty(agicUserAssignedIdentityId) ? {
              userAssignedIdentityId: agicUserAssignedIdentityId
            } : {})
          }
        }
      } : {})
    }
    apiServerAccessProfile: {
      enablePrivateCluster: enablePrivateCluster
    }
  }
}

// Add Diagnostic Settings resource for Azure Monitor integration
resource aksDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceResourceId)) {
  name: '${aksName}-diagnostic-settings'
  scope: aks
  properties: {
    workspaceId: logAnalyticsWorkspaceResourceId
    logs: diagnosticSettings.logs
    metrics: diagnosticSettings.metrics
  }
}

output aksId string = aks.id
output aksName string = aks.name
output controlPlaneIdentityId string = identityType == 'SystemAssigned' 
  ? aks.identity.principalId 
  : (length(userAssignedIdentities) > 0 
    ? reference(userAssignedIdentities[0], '2023-01-31').principalId 
    : '')
output kubeletIdentityObjectId string = aks.properties.identityProfile.kubeletidentity.objectId
output oidcIssuerUrl string = aks.properties.oidcIssuerProfile.issuerURL
output agicIdentityPrincipalId string = aks.properties.addonProfiles.ingressApplicationGateway.identity.objectId
