# Landing Zone Infrastructure - SecureSharer

This directory contains the foundational identity and access management infrastructure for the SecureSharer project, specifically designed for Static Web Apps (SWA) deployment patterns.

## Overview

The landing zone establishes the core identity and access management components required for deploying and managing SecureSharer workloads using Static Web Apps and Container Apps.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Static Web Apps Landing Zone                         │
├─────────────────────────────────────────────────────────────────────────┤
│  SWA Resource Group                                                     │
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
```

## Key Components

- **User-Assigned Managed Identities**: Provides secure, keyless authentication for Azure services
- **GitHub Federation**: Enables passwordless CI/CD authentication from GitHub Actions
- **RBAC Role Assignments**: Implements principle of least privilege access control
- **Resource Naming**: Uses SecureSharer-specific naming conventions (`ss-*`)

## Security Features

- Uses managed identities to eliminate credential management
- Implements federated identity for secure CI/CD without secrets
- Applies minimal RBAC permissions based on workload requirements
- Follows Azure Well-Architected security pillar guidelines

## Deployment

This template operates at subscription scope and is designed to be deployed first in the SecureSharer infrastructure pipeline.

### Prerequisites

- Azure subscription with sufficient permissions
- GitHub repository configured for OpenID Connect federation

### Parameters

Key parameters include:
- `projectCode`: Set to `'ss'` for SecureSharer
- `environmentName`: Target environment (`dev` or `prod`)
- `resourceLocation`: Azure region (default: `spaincentral`)
- `tenantId`: Azure AD tenant ID

## Usage

This landing zone should be deployed before any platform or workload infrastructure components.

```bash
az deployment sub create \
  --location spaincentral \
  --template-file main.bicep \
  --parameters @aks-dev.bicepparam
```