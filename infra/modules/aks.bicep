@description('Location of the AKS cluster')
param location string

@description('Name of the AKS cluster')
param aksName string

@description('DNS prefix for the AKS cluster')
param dnsPrefix string = uniqueString(resourceGroup().id, aksName)

@description('Kubernetes version for the AKS cluster')
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

resource aks 'Microsoft.ContainerService/managedClusters@2023-10-01' = {
  tags: tags
  name: aksName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    disableLocalAccounts: true
    enableRBAC: true
    aadProfile: {
      managed: true
      enableAzureRBAC: false
      adminGroupObjectIDs: aksAdminGroupObjectIds
    }
    oidcIssuerProfile: {
      enabled: true
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
    ]
    dnsPrefix: dnsPrefix
    kubernetesVersion: kubernetesVersion
    networkProfile: {
      networkPlugin: 'azure'
      networkPluginMode: 'overlay'
      networkPolicy: 'azure'     
      loadBalancerSku: 'Standard'
      serviceCidr: '10.1.0.0/16'
      dnsServiceIP: '10.1.0.10'
    }
    addonProfiles: {
      azureKeyvaultSecretsProvider: {
        enabled: true
        config: {
          enableSecretRotation: 'false'
        }
      }
      ingressApplicationGateway: {
        enabled: !empty(applicationGatewayIdForAgic)
        config: !empty(applicationGatewayIdForAgic) ? {
          applicationGatewayId: applicationGatewayIdForAgic
          watchNamespace: 'kube-system'
        } : {}
      }
    }
  }
}

output aksId string = aks.id
output aksName string = aks.name
output controlPlaneIdentityId string = aks.identity.principalId
output oidcIssuerUrl string = aks.properties.oidcIssuerProfile.issuerURL
