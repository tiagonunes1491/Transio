# Platform Infrastructure (AKS) - SecureSharer

This directory contains the Azure Kubernetes Service (AKS) platform infrastructure for the SecureSharer project. It provides a comprehensive, production-ready container orchestration platform with advanced security, networking, and monitoring capabilities.

## Overview

This deployment creates a complete AKS platform infrastructure designed to host containerized workloads for the SecureSharer application with enterprise-grade security, networking, and operational features.

## Architecture

The platform includes:

- **Azure Kubernetes Service (AKS)**: Managed Kubernetes cluster with auto-scaling
- **Virtual Network**: Dedicated network with subnet segmentation
- **Application Gateway**: Layer 7 load balancer with SSL termination
- **Key Vault**: Secure storage for secrets and certificates
- **Container Registry**: Private container image storage
- **Log Analytics**: Centralized logging and monitoring
- **Network Security Groups**: Traffic filtering and security policies

## Key Features

### Compute & Orchestration
- Managed AKS cluster with system and user node pools
- Auto-scaling based on resource demand
- Azure AD integration for RBAC

### Networking
- Dedicated virtual network with subnet isolation
- Application Gateway for ingress traffic management
- Network Security Groups for traffic filtering
- Private endpoints for secure service connectivity

### Security
- Key Vault integration for secrets management
- Managed identities for secure authentication
- Network isolation and private connectivity
- RBAC for granular access control

### Monitoring & Operations
- Log Analytics workspace for centralized logging
- Azure Monitor integration
- Health monitoring and alerting

## Resource Naming

All resources follow the SecureSharer naming convention:
- Pattern: `ss-{env}-{service}-{resourceType}`
- Examples:
  - `ss-d-aks-rg` (Development AKS Resource Group)
  - `ss-p-aks-aks` (Production AKS Cluster)
  - `ss-d-aks-kv` (Development Key Vault)

## Security Considerations

- **Network Isolation**: Dedicated VNet with subnet segmentation
- **Private Connectivity**: Private endpoints for Azure services
- **Identity Management**: Managed identities and Azure AD integration
- **Secrets Management**: Key Vault integration with CSI driver
- **Network Security**: NSG rules and Application Gateway WAF

## Deployment

### Prerequisites

- Azure subscription with sufficient permissions
- Landing zone infrastructure deployed
- Resource group created

### Parameters

Key parameters include:
- `projectCode`: Set to `'ss'` for SecureSharer
- `serviceCode`: Set to `'aks'` for this platform
- `environmentName`: Target environment (`dev` or `prod`)
- `resourceLocation`: Azure region (default: `spaincentral`)

### Deployment Command

```bash
az deployment group create \
  --resource-group ss-dev-aks-rg \
  --template-file main.bicep \
  --parameters @main.bicepparam
```

## Integration Points

This platform is designed to integrate with:
- SecureSharer application workloads
- Shared services (Container Registry, Key Vault)
- Monitoring and logging infrastructure
- CI/CD pipelines from GitHub Actions

## Operational Considerations

- **Scaling**: Configured for automatic scaling based on resource demand
- **Monitoring**: Integrated with Azure Monitor and Log Analytics
- **Backup**: Persistent volume backup strategies should be implemented
- **Updates**: Kubernetes version updates should be planned and tested