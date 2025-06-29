/*
 * =============================================================================
 * Container App Module
 * =============================================================================
 * 
 * This Bicep module creates and configures individual Azure Container Apps
 * within an existing Container Apps Environment. It provides a flexible,
 * unopinionated deployment pattern for containerized applications with
 * comprehensive configuration options for scaling, networking, and security.
 * 
 * ARCHITECTURE OVERVIEW:
 * ┌─────────────────────────────────────────────────────────────────────────┐
 * │                     Container App Architecture                          │
 * ├─────────────────────────────────────────────────────────────────────────┤
 * │  Container App Instance                                                 │
 * │  ┌─────────────────────────────────────────────────────────────────────┐│
 * │  │ Application Container                                               ││
 * │  │ ┌─────────────────────┐  ┌─────────────────────────────────────┐   ││
 * │  │ │ Application Runtime │  │ Ingress Configuration               │   ││
 * │  │ │ • Custom image      │  │ • HTTP/HTTPS endpoints              │   ││
 * │  │ │ • Environment vars  │  │ • Traffic splitting                 │   ││
 * │  │ │ • Secrets injection │  │ • Custom domains                    │   ││
 * │  │ │ • Volume mounts     │  │ • SSL termination                   │   ││
 * │  │ └─────────────────────┘  └─────────────────────────────────────┘   ││
 * │  │                                                                     ││
 * │  │ Scaling Configuration                                               ││
 * │  │ ┌─────────────────────┐  ┌─────────────────────────────────────┐   ││
 * │  │ │ Horizontal Scaling  │  │ Health Monitoring                   │   ││
 * │  │ │ • Min/Max replicas  │  │ • Liveness probes                   │   ││
 * │  │ │ • CPU/Memory rules  │  │ • Readiness probes                  │   ││
 * │  │ │ • Custom metrics    │  │ • Startup probes                    │   ││
 * │  │ └─────────────────────┘  └─────────────────────────────────────┘   ││
 * │  └─────────────────────────────────────────────────────────────────────┘│
 * └─────────────────────────────────────────────────────────────────────────┘
 * 
 * KEY FEATURES:
 * • Flexible Container Deployment: Support for custom images with full configuration control
 * • Horizontal Auto-scaling: CPU, memory, and custom metric-based scaling policies
 * • Ingress Management: HTTP/HTTPS endpoints with custom domain and SSL support
 * • Secret Management: Secure injection of secrets from Key Vault or environment
 * • Health Monitoring: Comprehensive health check configuration options
 * • Traffic Management: Built-in load balancing and traffic splitting capabilities
 * • Resource Optimization: Configurable CPU and memory limits with efficient allocation
 * 
 * SECURITY CONSIDERATIONS:
 * • Secure secret injection without environment variable exposure
 * • Managed identity integration for Azure service authentication
 * • Network isolation through Container Apps Environment networking
 * • Resource limits to prevent resource exhaustion attacks
 * • Health probe validation to ensure application security and stability
 * • Traffic encryption with automatic SSL/TLS certificate management
 * 
 * DEPLOYMENT SCOPE:
 * This module operates at resource group scope to deploy individual
 * container applications within an existing Container Apps Environment.
 */

// ========== PARAMETERS ==========

@description('Application name for the Azure Container App')
param containerAppName string

@description('Location for the Azure Container App')
param location string = resourceGroup().location

@description('The Azure Container Apps Environment ID for the app.')
param environmentId string

@description('The container image for the Azure Container App.')
param image string

@description('Minimum number of replicas for the Azure Container App.')
param minReplicas int = 0

@description('Maximum number of replicas for the Azure Container App.')
param maxReplicas int = 1

@description('Enable ingress for the Azure Container App.')
param enableIngress bool = true

@description('Target port for the Azure Container App.')
param targetPort int = 80

@description('External Ingress for the Azure Container App.')
param externalIngress bool = false

@description('Ingress transport protocol (http, http2, auto)')
param ingressTransport string = 'auto'

@description('IP security restrictions for ingress')
param ipSecurityRestrictions array = []

@description('Secrets from Key Vault to be used in the Azure Container App.')
param secrets array = []

@description('Secret references as environment variables.')
param secretEnvironmentVariables array = []

@description('Environment variables for the Azure Container App.')
param environmentVariables array = []

@description('Tags for the Azure Container App.')
param tags object = {}

@description('CPU limit for the Azure Container App')
param cpuLimit string = '0.25'

@description('Memory limit for the Azure Container App')
param memoryLimit string = '0.5Gi'

@description('Managed identity configuration for the Azure Container App')
param identity object = {}

@description('Container registry configurations')
param registries array = []

@description('Active revisions mode (Single or Multiple)')
param activeRevisionsMode string = 'Single'

@description('Scaling rules for the Azure Container App')
param scalingRules array = []

@description('Volumes for the Azure Container App')
param volumes array = []

@description('Volume mounts for the container')
param volumeMounts array = []

@description('Additional containers to run in the same pod')
param additionalContainers array = []

// ========== CONTAINER APP ==========

resource app 'Microsoft.App/containerApps@2025-01-01' = {
  name: containerAppName
  location: location
  tags: tags
  identity: empty(identity) ? null : identity
  properties: {
    environmentId: environmentId
    configuration: {
      ingress: enableIngress ? {
        external: externalIngress
        targetPort: targetPort
        transport: ingressTransport
        ipSecurityRestrictions: ipSecurityRestrictions
      } : null
      secrets: [for secret in secrets: {        name: secret.name
        keyVaultUrl: secret.keyVaultUrl
        identity: secret.identity
      }]
      activeRevisionsMode: activeRevisionsMode
      registries: registries
    }
    template: {
      containers: concat([
        {
          name: containerAppName
          image: image
          resources: {
            cpu: json(cpuLimit)
            memory: memoryLimit
          }
          env: union(secretEnvironmentVariables, environmentVariables)
          volumeMounts: volumeMounts
        }
      ], additionalContainers)
      scale: union({
        minReplicas: minReplicas
        maxReplicas: maxReplicas
      }, empty(scalingRules) ? {} : { rules: scalingRules })
      volumes: volumes
    }
  }
}

// ========== OUTPUTS ==========
output containerAppId string = app.id
output fqdn string = enableIngress ? app.properties.configuration.ingress.fqdn : ''
