# Application Deployment (SWA) - Transio

This directory contains the actual Transio application deployment infrastructure using Static Web Apps and Container Apps. It deploys the frontend and backend components onto the previously established platform infrastructure.

## Overview

This deployment creates the actual Transio application components, including the React frontend hosted on Static Web Apps and the Python Flask backend running on Container Apps, with secure connectivity and proper configuration management.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Transio Application Deployment                  │
├─────────────────────────────────────────────────────────────────────────┤
│  Application Resource Group                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐│
│  │ Frontend Components                                                 ││
│  │ ┌─────────────────────┐                                           ││
│  │ │ Static Web App      │ ← GitHub Integration                      ││
│  │ │ • React Frontend    │ ← Custom Domain Support                   ││
│  │ │ • Global CDN        │ ← SSL/TLS Termination                     ││
│  │ │ • Authentication    │                                           ││
│  │ └─────────────────────┘                                           ││
│  │                                                                    ││
│  │ Backend Components                                                 ││
│  │ ┌─────────────────────┐                                           ││
│  │ │ Container App       │ ← Managed Identity Authentication         ││
│  │ │ • Flask API Backend │ ← Environment Variables from Key Vault    ││
│  │ │ • Auto Scaling      │ ← Private Network Connectivity            ││
│  │ │ • Health Probes     │ ← Container Registry Integration          ││
│  │ └─────────────────────┘                                           ││
│  └─────────────────────────────────────────────────────────────────────┘│
│                                                                         │
│  Integration Points:                                                    │
│  • Container Apps Environment (existing platform infrastructure)       │
│  • User-Assigned Managed Identity (from identity deployment)           │
│  • Key Vault secrets injection for secure configuration                │
│  • Container Registry for backend image deployment                     │
│  • Cosmos DB for application data storage                              │
└─────────────────────────────────────────────────────────────────────────┘
```

## Key Components

### Frontend (Static Web App)
- **React Application**: Modern web interface for Transio
- **Global CDN**: Worldwide content delivery for optimal performance
- **GitHub Integration**: Automated deployment from source code
- **SSL/TLS**: Automatic certificate management and HTTPS enforcement
- **Custom Domains**: Support for production domain configuration

### Backend (Container App)
- **Flask API**: Python-based REST API for Transio functionality
- **Auto Scaling**: Dynamic scaling based on CPU/memory utilization
- **Health Monitoring**: Built-in health checks and observability
- **Secure Configuration**: Environment variables from Key Vault
- **Container Registry**: Private image storage and deployment

### Security & Identity
- **User-Assigned Managed Identity**: Secure authentication without credentials
- **Key Vault Integration**: Secure secrets and configuration management
- **RBAC Assignments**: Granular permissions for service access
- **Network Isolation**: Backend services in private network

## Transio-Specific Configuration

### Application Features
- **Secret Sharing**: Secure temporary secret sharing functionality
- **Encryption**: Client-side and server-side encryption capabilities
- **Time-based Expiration**: Automatic secret expiration
- **Access Control**: Link-based access with optional passwords
- **Audit Trail**: Comprehensive logging of secret access

### Database Integration
- **Cosmos DB**: NoSQL database for storing encrypted secrets metadata
- **Private Connectivity**: Database access via private endpoints
- **RBAC**: Cosmos DB Data Contributor role for container app identity

## Resource Naming

Application resources follow Transio naming convention:
- Pattern: `ts-{env}-swa-{resourceType}`
- Examples:
  - `ts-d-swa-swa` (Development Static Web App)
  - `ts-p-swa-ca` (Production Container App)
  - `ts-d-swa-id-ca-backend` (Backend Managed Identity)

## Environment Configuration

### Development Environment
- `environmentName`: `dev`
- Container image: Development/staging images
- Scaling: Minimal resources for cost optimization
- Monitoring: Basic monitoring and logging

### Production Environment
- `environmentName`: `prod`
- Container image: Production-ready images
- Scaling: Production-grade auto-scaling rules
- Monitoring: Comprehensive monitoring and alerting

## Deployment

### Prerequisites

- Platform infrastructure deployed (`10-platform-swa`)
- Container image built and pushed to Container Registry
- Application secrets configured in Key Vault
- GitHub repository configured for Static Web Apps

### Parameters

Key Transio-specific parameters:
- `projectCode`: Set to `'ts'` for Transio
- `serviceCode`: Set to `'swa'` for this application
- `containerImage`: Full path to Transio backend container image
- `keyVaultSecrets`: Array of secrets required by the application
- `environmentVariables`: Application configuration variables

### Deployment Command

```bash
az deployment group create \
  --resource-group ts-dev-swa-rg \
  --template-file main.bicep \
  --parameters @main.dev.bicepparam
```

## Application Configuration

### Key Vault Secrets
The Transio application requires the following secrets:
- Database connection strings
- Encryption keys
- Third-party API keys
- Authentication configuration

### Environment Variables
- `AZURE_CLIENT_ID`: Managed identity client ID (auto-configured)
- Database connection parameters
- Application-specific configuration

## Monitoring & Operations

### Health Monitoring
- Container App health probes configured
- Application-level health endpoints
- Database connectivity monitoring

### Logging
- Application logs sent to Log Analytics
- Performance metrics and telemetry
- Security audit logs

### Scaling
- CPU and memory-based auto-scaling
- Custom metrics scaling (if configured)
- Manual scaling capabilities

## Security Considerations

- **Zero Secrets in Code**: All sensitive configuration via Key Vault
- **Network Isolation**: Backend services not publicly accessible
- **Managed Identity**: No credential management required
- **Encryption**: Data encrypted in transit and at rest
- **Access Control**: Role-based access to all Azure resources

## Integration Points

This application integrates with:
- **GitHub**: Source code and CI/CD automation
- **Container Registry**: Backend image storage and deployment
- **Key Vault**: Secure configuration and secrets management
- **Cosmos DB**: Application data persistence
- **Log Analytics**: Operational monitoring and troubleshooting