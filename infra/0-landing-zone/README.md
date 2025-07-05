# Landing Zone Infrastructure - Transio

This directory contains the foundational identity and access management infrastructure for the Transio project. This landing zone is platform-agnostic and supports both Azure Kubernetes Service (AKS) and Static Web Apps (SWA) deployment patterns.

## Overview

The landing zone establishes the core identity and access management components required for deploying and managing Transio workloads across different platform architectures, including both containerized workloads on AKS and serverless workloads using Static Web Apps with Container Apps.

## Architecture

This landing zone is platform-agnostic and can be deployed with either AKS or SWA service configurations:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                       Platform-Agnostic Landing Zone                   │
├─────────────────────────────────────────────────────────────────────────┤
│  Service-Specific Resource Group                                       │
│  ┌─────────────────────────────────────────────────────────────────────┐│
│  │                                                                     ││
│  │  ┌─────────────────────┐  ┌─────────────────────────────────────┐  ││
│  │  │ User-Assigned       │  │ GitHub Federated                    │  ││
│  │  │ Managed Identities  │──│ Credentials                         │  ││
│  │  │                     │  │                                     │  ││
│  │  │ • Creator Identity  │  │ • Environment-based                 │  ││
│  │  │ • ACR Push Identity │  │ • Passwordless Authentication       │  ││
│  │  └─────────────────────┘  └─────────────────────────────────────┘  ││
│  │                                                                     ││
│  │  ┌─────────────────────────────────────────────────────────────────┐││
│  │  │ RBAC Role Assignments                                          │││
│  │  │ • Contributor permissions for infrastructure creation          │││
│  │  │ • AcrPush permissions for container registry operations        │││
│  │  └─────────────────────────────────────────────────────────────────┘││
│  └─────────────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────────┘

Deployment Options:
├── AKS Pattern: Creates ts-{env}-aks-rg with AKS-specific identities
└── SWA Pattern: Creates ts-{env}-swa-rg with SWA-specific identities
```

## Key Components

- **User-Assigned Managed Identities**: Provides secure, keyless authentication for Azure services
- **GitHub Federation**: Enables passwordless CI/CD authentication from GitHub Actions
- **RBAC Role Assignments**: Implements principle of least privilege access control
- **Resource Naming**: Uses Transio-specific naming conventions with configurable service codes
- **Platform Flexibility**: Supports both AKS (`ts-{env}-aks-*`) and SWA (`ts-{env}-swa-*`) naming patterns

## Security Features

- Uses managed identities to eliminate credential management
- Implements federated identity for secure CI/CD without secrets
- Applies minimal RBAC permissions based on workload requirements
- Follows Azure Well-Architected security pillar guidelines

## Deployment

This template operates at subscription scope and is designed to be deployed first in the Transio infrastructure pipeline. The same landing zone template supports both AKS and SWA deployment patterns through different parameter configurations.

### Prerequisites

- Azure subscription with sufficient permissions
- GitHub repository configured for OpenID Connect federation

### Parameters

Key parameters include:
- `projectCode`: Set to `'ts'` for Transio
- `serviceCode`: Platform identifier (`'aks'` for Kubernetes or `'swa'` for Static Web Apps)
- `environmentName`: Target environment (`dev` or `prod`)
- `resourceLocation`: Azure region (default: `spaincentral`)
- `tenantId`: Azure AD tenant ID
- `workloadIdentities`: Platform-specific identity configurations

## Usage

This landing zone should be deployed before any platform or workload infrastructure components. Choose the appropriate parameter file based on your target platform:

### For AKS Deployment Pattern

```bash
az deployment sub create \
  --location spaincentral \
  --template-file main.bicep \
  --parameters @aks-dev.bicepparam
```

This creates: `ts-d-aks-rg` resource group with AKS-specific managed identities.

### For Static Web Apps Deployment Pattern

```bash
az deployment sub create \
  --location spaincentral \
  --template-file main.bicep \
  --parameters @swa-dev.bicepparam
```

This creates: `ts-d-swa-rg` resource group with SWA-specific managed identities.

## Next Steps

After deploying the landing zone, proceed with the appropriate platform infrastructure:

- **For AKS**: Deploy `10-platform-aks` infrastructure
- **For SWA**: Deploy `10-platform-swa` infrastructure