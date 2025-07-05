# Platform Infrastructure (SWA) - Transio

This directory contains the Static Web Apps (SWA) platform infrastructure for the Transio project. It establishes a comprehensive platform environment that supports both Container Apps and Static Web Apps with secure networking, identity management, and monitoring capabilities.

## Overview

This deployment creates the foundational platform infrastructure required for hosting the Transio application using a modern Static Web Apps + Container Apps architecture pattern.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                       SWA Platform Infrastructure                       │
├─────────────────────────────────────────────────────────────────────────┤
│  Virtual Network (10.0.0.0/16)                                         │
│  ┌─────────────────────────────────────────────────────────────────────┐│
│  │ Container Apps Subnet (10.0.10.0/23)                              ││
│  │ ┌─────────────────────┐                                          ││
│  │ │ Container Apps      │                                          ││
│  │ │ Environment         │                                          ││
│  │ │ • Backend Services  │                                          ││
│  │ │ • API Endpoints     │                                          ││
│  │ └─────────────────────┘                                          ││
│  │                                                                    ││
│  │ Private Endpoints Subnet (10.0.30.0/24)                          ││
│  │ ┌─────────────────────┐  ┌─────────────────────────────────────┐  ││
│  │ │ Key Vault PE        │  │ Cosmos DB PE                        │  ││
│  │ │ Container Registry  │  │ Log Analytics PE                    │  ││
│  │ │ PE                  │  │                                     │  ││
│  │ └─────────────────────┘  └─────────────────────────────────────┘  ││
│  └─────────────────────────────────────────────────────────────────────┘│
│                                                                         │
│  External Services (Connected via Internet):                           │
│  • Static Web Apps (Global CDN) - Frontend hosting                     │
│  • GitHub Actions - CI/CD with federated authentication               │
│  • Azure services accessible via private endpoints                     │
└─────────────────────────────────────────────────────────────────────────┘
```

## Key Components

### Networking Infrastructure
- **Virtual Network**: Dedicated network (10.0.0.0/16) with subnet segmentation
- **Container Apps Subnet**: Dedicated subnet for backend API services
- **Private Endpoints Subnet**: Isolated subnet for secure service connectivity
- **Network Security Groups**: Traffic filtering and security policies

### Platform Services
- **Container Apps Environment**: Managed serverless container platform
- **Key Vault**: Secure secrets and configuration management
- **Container Registry**: Private container image storage
- **Cosmos DB**: NoSQL database for application data
- **Log Analytics**: Centralized monitoring and logging

### Security & Identity
- **Private Endpoints**: Secure connectivity to shared services
- **Managed Identities**: Keyless authentication for platform services
- **Network Security Groups**: Granular network access control

## Resource Naming

All resources follow the Transio naming convention:
- Pattern: `ts-{env}-swa-{resourceType}`
- Examples:
  - `ts-d-swa-rg` (Development SWA Resource Group)
  - `ts-p-swa-cae` (Production Container Apps Environment)
  - `ts-d-swa-kv` (Development Key Vault)

## Security Features

- **Network Isolation**: Dedicated virtual network and subnet segmentation
- **Private Connectivity**: All shared services accessible via private endpoints
- **Zero-Trust Architecture**: No public endpoints for backend services
- **Secrets Management**: Key Vault integration for secure configuration
- **Identity-Based Access**: Managed identities eliminate credential management

## Deployment

### Prerequisites

- Azure subscription with sufficient permissions
- Landing zone infrastructure deployed
- Resource group created

### Parameters

Key Transio-specific parameters:
- `projectCode`: Set to `'ts'` for Transio
- `serviceCode`: Set to `'swa'` for this platform
- `environmentName`: Target environment (`dev` or `prod`)
- `resourceLocation`: Azure region (default: `spaincentral`)
- `addressSpace`: Virtual network CIDR (default: `10.0.0.0/16`)

### Deployment Command

```bash
az deployment group create \
  --resource-group ts-dev-swa-rg \
  --template-file main.bicep \
  --parameters @main.dev.bicepparam
```

## Integration Points

This platform provides the foundation for:
- **Transio Frontend**: Static Web Apps hosting React application
- **Transio Backend**: Container Apps hosting API services
- **Data Layer**: Cosmos DB for application data storage
- **Configuration**: Key Vault for secrets and app settings
- **Monitoring**: Log Analytics for operational insights

## Operational Considerations

- **Scaling**: Container Apps Environment configured for auto-scaling
- **Monitoring**: Integrated with Azure Monitor and Application Insights
- **Security**: Regular review of NSG rules and private endpoint configurations
- **Cost Optimization**: Monitor Container Apps consumption and scale appropriately

## Next Steps

After deploying this platform, you can deploy:
1. Transio application workloads (`20-workload-swa`)
2. Application-specific configuration and secrets
3. Monitoring and alerting rules