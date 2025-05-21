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

output uamiDetails array = [
  for i  in range(0, length(uamiNames)): {
    name: uami[i].name
    id: uami[i].id
    principalId: uami[i].properties.principalId
    clientId: uami[i].properties.clientId
  }
]
