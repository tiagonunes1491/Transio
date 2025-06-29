/*
 * =============================================================================
 * User-Assigned Managed Identity Module
 * =============================================================================
 * 
 * This Bicep module creates one or more Azure User-Assigned Managed Identities
 * (UAMIs) for secure service authentication.
 * It eliminates the need for credential management while providing a centralized
 * identity solution for Azure resource authentication and authorization.
 * 
 * ARCHITECTURE OVERVIEW:
 * ┌─────────────────────────────────────────────────────────────────────────┐
 * │                 User-Assigned Managed Identity                          │
 * ├─────────────────────────────────────────────────────────────────────────┤
 * │  Identity Management                                                    │
 * │  ┌─────────────────────────────────────────────────────────────────────┐│
 * │  │ Azure AD Integration                                                ││
 * │  │ ┌─────────────────────┐  ┌─────────────────────────────────────┐   ││
 * │  │ │ Principal ID        │  │ Client ID                           │   ││
 * │  │ │ • Azure AD identity │  │ • Application identity              │   ││
 * │  │ │ • RBAC assignments  │  │ • Service authentication            │   ││
 * │  │ │ • Audit trail       │  │ • Federation support                │   ││
 * │  │ └─────────────────────┘  └─────────────────────────────────────┘   ││
 * │  │                                                                     ││
 * │  │ Integration Points                                                  ││
 * │  │ ┌─────────────────────┐  ┌─────────────────────────────────────┐   ││
 * │  │ │ Azure Services      │  │ External Systems                    │   ││
 * │  │ │ • Container Apps    │  │ • GitHub Actions                    │   ││
 * │  │ │ • Key Vault         │  │ • Third-party services              │   ││
 * │  │ │ • Storage Accounts  │  │ • Federation credentials            │   ││
 * │  │ └─────────────────────┘  └─────────────────────────────────────┘   ││
 * │  └─────────────────────────────────────────────────────────────────────┘│
 * └─────────────────────────────────────────────────────────────────────────┘
 * 
 * KEY FEATURES:
 * • Multi-Identity Support: Creates multiple UAMIs from a single module deployment
 * • Zero-Credential Authentication: Eliminates password and certificate management
 * • Federation Ready: Supports federated identity credentials for CI/CD systems
 * • RBAC Integration: Seamless integration with Azure role-based access control
 * • Cross-Resource Access: Identity reusable across multiple Azure resources
 * • Audit Capabilities: Complete audit trail for identity operations and access
 * • Scalable Design: Array-based parameter input for efficient bulk deployments
 * 
 * SECURITY CONSIDERATIONS:
 * • Azure AD native integration for consistent identity management
 * • No stored credentials reducing attack surface and maintenance overhead
 * • Federation support for secure external system integration
 * • Principal ID and Client ID separation for different authentication scenarios
 * • Comprehensive audit logging for all identity operations
 * • Role assignment separation for principle of least privilege implementation
 * 
 * DEPLOYMENT SCOPE:
 * This module operates at resource group scope to create managed identities
 * that can be referenced and used by other Azure resources within the
 * subscription for secure authentication scenarios.
 */
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
