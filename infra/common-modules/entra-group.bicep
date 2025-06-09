// Bicep module for creating Entra ID security group for GitHub Actions UAMI
// This module creates a security group and assigns the UAMI to it

extension microsoftGraphV1

targetScope = 'tenant'

@description('Name of the security group to create')
param groupName string

@description('Description of the security group')
param groupDescription string = 'Security group for GitHub Actions managed identities'

@description('Principal ID of the User Assigned Managed Identity to add to the group')
param uamiPrincipalId string

// Create the security group
resource securityGroup 'Microsoft.Graph/groups@v1.0' = {
  uniqueName: groupName
  displayName: groupName
  description: groupDescription
  mailNickname: replace(groupName, '-', '')
  securityEnabled: true
  mailEnabled: false
  groupTypes: []
  owners: []
  members: [
    uamiPrincipalId
  ]
}

// Outputs
output groupId string = securityGroup.id
output groupDisplayName string = securityGroup.displayName
output groupUniqueName string = securityGroup.uniqueName
