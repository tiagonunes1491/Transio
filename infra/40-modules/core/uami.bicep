// Module: core/uami.bicep
// Description: Deploys one or more Azure User Assigned Managed Identities (UAMIs) for secure service authentication.
// Parameters:
//   - uamiLocation: Location where the UAMIs will be created. Defaults to the resource group's location.
//   - uamiNames: Array of UAMI names to create.
//   - tags: Tags to apply to each UAMI resource.
// Resources:
//   - Microsoft.ManagedIdentity/userAssignedIdentities: Creates a UAMI for each name provided in uamiNames.
// Outputs:
//   - uamis: Array of objects containing the name, resource ID, clientId, and principalId for each created UAMI.
// Usage:
//   Use this module to provision one or more managed identities for use by Azure resources, supporting secure authentication and authorization.
//
// Example:
//   module uami 'core/uami.bicep' = {
//     name: 'create-uami'
//     scope: resourceGroup()
//     params: {
//       uamiLocation: 'westeurope'
//       uamiNames: ['my-identity']
//       tags: {
//         environment: 'dev'
//         owner: 'alice@example.com'
//       }
//     }
//   }

@description('Location of the User Assigned Managed Identity (UAMI)')
param uamiLocation string = resourceGroup().location

@description('Names of the User Assigned Managed Identity (UAMI) to create')
param uamiNames array = []

@description('Tags for the User Assigned Managed Identity (UAMI)')
param tags object = {}

// Create User Assigned Managed Identities using a loop to support multiple identities
// UAMIs provide secure authentication without storing credentials in code or configuration
resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = [
  for name in uamiNames: {
    name: name
    location: uamiLocation
    tags: tags
  }
]

// Output comprehensive UAMI details for downstream consumption
// Provides all essential identifiers needed for role assignments and federated credentials
output uamis array = [
  for (name, idx) in uamiNames: {
    name: name                                    // UAMI resource name for reference
    id: uami[idx].id                             // Full Azure resource ID for ARM operations
    clientId: uami[idx].properties.clientId     // Application ID for OIDC authentication
    principalId: uami[idx].properties.principalId // Object ID for RBAC role assignments
  }
]
