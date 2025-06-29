/*
 * =============================================================================
 * Application Gateway RBAC Assignment Module
 * =============================================================================
 * 
 * This Bicep module creates role-based access control (RBAC) assignments for
 * Azure Application Gateway resources. It provides standardized permission
 * management for managed identities and service principals that need to
 * interact with Application Gateway resources for ingress control and
 * traffic management scenarios.
 * 
 * ARCHITECTURE OVERVIEW:
 * ┌─────────────────────────────────────────────────────────────────────────┐
 * │                Application Gateway RBAC Assignment                      │
 * ├─────────────────────────────────────────────────────────────────────────┤
 * │  Azure Authorization                                                    │
 * │  ┌─────────────────────────────────────────────────────────────────────┐│
 * │  │ Role Assignment                                                     ││
 * │  │ ┌─────────────────────┐  ┌─────────────────────────────────────┐   ││
 * │  │ │ Principal Identity  │  │ Role Definition                     │   ││
 * │  │ │ • Managed Identity  │──│ • Application Gateway Contributor   │   ││
 * │  │ │ • Service Principal │  │ • Network Contributor               │   ││
 * │  │ │ • AKS cluster       │  │ • Custom ingress roles             │   ││
 * │  │ └─────────────────────┘  └─────────────────────────────────────┘   ││
 * │  └─────────────────────────────────────────────────────────────────────┘│
 * │                                                                         │
 * │  Application Gateway Scope                                              │
 * │  ┌─────────────────────────────────────────────────────────────────────┐│
 * │  │ • Traffic routing configuration                                     ││
 * │  │ • SSL certificate management                                        ││
 * │  │ • Backend pool management                                           ││
 * │  │ • Health probe configuration                                        ││
 * │  │ • WAF policy management                                             ││
 * │  └─────────────────────────────────────────────────────────────────────┘│
 * └─────────────────────────────────────────────────────────────────────────┘
 * 
 * COMMON USE CASES:
 * • AKS ingress controller access to Application Gateway
 * • Automation tooling for traffic management
 * • DevOps pipelines for deployment automation
 */

@description('Full resource ID of the Application Gateway')
param appGwId string

@description('Object ID of the principal (UAMI, SP, AKS, etc.)')
param principalId string

@description('Full roleDefinitionId path or built-in GUID of the role to assign')
param roleDefinitionId string


resource appGw 'Microsoft.Network/applicationGateways@2023-05-01' existing = {
  scope: resourceGroup()
  name: split(appGwId, '/')[8]
}

resource assignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: appGw
  name: guid(appGw.id, principalId, roleDefinitionId)
  properties: {
    principalId: principalId
    roleDefinitionId: contains(roleDefinitionId, '/providers/')
      ? roleDefinitionId
      : subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
    principalType: 'ServicePrincipal'
  }
}

output assignmentId string = assignment.id
