@description('Location of the User Assigned Managed Identity (UAMI)')
param uamiLocation string = 'spaincentral'

@description('Names of the User Assigned Managed Identity (UAMI) to create')
param uamiNames array = []

@description('Tags for the User Assigned Managed Identity (UAMI)')
param tags object = {}

resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = [
  for name in uamiNames: {
  name: name
  location: uamiLocation
  tags: tags
}]

output uamiIds array = [for i in range(0, length(uamiNames)): uami[i].id]
output uamiClientIds array = [for i in range(0, length(uamiNames)): uami[i].properties.clientId]
output uamiPrincipalIds array = [for i in range(0, length(uamiNames)): uami[i].properties.principalId]
