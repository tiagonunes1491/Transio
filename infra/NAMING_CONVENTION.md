# Transio Infrastructure Naming Convention

This document describes the standardized naming convention implemented across all Transio infrastructure, based on Cloud Adoption Framework (CAF) standards.

## Naming Pattern

All Azure resources follow the pattern: `{proj}-{env}-{svc}-{rtype}{-seq}`

### Components

| Component | Description | Example | Rules |
|-----------|-------------|---------|-------|
| **proj** | Project code (2-3 letters) | `ts` | Lowercase letters only, `^[a-z]{2,3}$` |
| **env** | Environment code | `d`, `s`, `p`, `sh` | dev→d, staging→s, prod→p, shared→sh |
| **svc** | Service code (2-4 letters) | `hub`, `aks`, `swa`, `plat` | Lowercase letters only, `^[a-z]{2,4}$` |
| **rtype** | Resource type code | `rg`, `acr`, `cosmos`, `id` | CAF standard abbreviations |
| **seq** | Optional sequence (01-99) | `01`, `02` | Two digits, optional |

### Resource Type Codes

| Azure Resource | Code | Example Name |
|---------------|------|--------------|
| Resource Group | `rg` | `ts-d-aks-rg` |
| Container Registry | `acr` | `tsshplatacr` (sanitized) |
| Cosmos DB | `cosmos` | `tsshplatcosmos` (sanitized) |
| Key Vault | `kv` | `tsdakskv` (sanitized) |
| Log Analytics | `log` | `ts-sh-hub-log` |
| Static Web App | `swa` | `ts-d-swa-swa` |
| Container App Environment | `cae` | `ts-d-swa-cae` |
| Container App | `ca` | `ts-d-swa-ca` |
| User Assigned Managed Identity | `id` | `ts-d-k8s-id` |
| Virtual Network | `vnet` | `ts-d-hub-vnet` |
| Private Endpoint | `pe` | `ts-d-aks-pe` |
| Subnet | `sub` | `ts-d-aks-sub` |

### Sanitization Rules

Some Azure resources have naming restrictions:
- **ACR and Cosmos DB**: Remove dashes, all lowercase (e.g., `ssshplatacr`)
- **Key Vault**: Remove dashes, all lowercase (e.g., `ssdakskv`)

## Service Codes

| Service Area | Code | Description |
|-------------|------|-------------|
| Shared Hub | `hub` | Connectivity and shared services |
| Shared Platform | `plat` | Cross-environment platform services |
| AKS Platform | `aks` | Kubernetes workloads |
| SWA/ACA Platform | `swa` | Static Web Apps and Container Apps |
| Management | `mgmt` | Identity and access management |

## Required Tags

All resources must include these standardized tags:

| Tag | Description | Pattern/Values | Example |
|-----|-------------|----------------|---------|
| `environment` | Deployment environment | `dev`, `staging`, `prod`, `shared` | `dev` |
| `project` | Project code | `^[a-z]{2,3}$` | `ts` |
| `service` | Service code | `^[a-z]{2,4}$` | `aks` |
| `costCenter` | Cost center code | `^[0-9]{4,6}$` | `1000` |
| `createdBy` | Creator information | `^[A-Za-z0-9 _-]+$` | `bicep-deployment` |
| `owner` | Resource owner | `^[a-z0-9-]+$` | `tiago-nunes` |
| `ownerEmail` | Owner email | Valid email format | `tiago.nunes@example.com` |
| `createdDate` | Creation date | `yyyy-MM-dd` | `2024-06-20` |
| `managedBy` | Management method | | `bicep` |
| `deployment` | Deployment reference | | `{deployment().name}` |

## Implementation

The naming convention is implemented through reusable Bicep modules:

### Naming Module
```bicep
module naming '../40-modules/core/naming.bicep' = {
  name: 'resource-naming'
  params: {
    projectCode: 'ts'
    environment: 'dev'
    serviceCode: 'aks'
    resourceType: 'rg'
    sequence: '' // optional
  }
}
// Usage: naming.outputs.resourceName
```

### Tagging Module
```bicep
module tags '../40-modules/core/tagging.bicep' = {
  name: 'resource-tagging'
  params: {
    environment: 'dev'
    project: 'ts'
    service: 'aks'
    costCenter: '1000'
    createdBy: 'bicep-deployment'
    owner: 'tiago-nunes'
    ownerEmail: 'tiago.nunes@example.com'
  }
}
// Usage: tags.outputs.tags
```

## Examples

### Resource Group Names
- Shared hub: `ts-sh-hub-rg`
- Dev AKS: `ts-d-aks-rg`
- Prod SWA: `ts-p-swa-rg`
- Management: `ts-d-mgmt-rg`

### Identity Names
- Dev K8s identity: `ts-d-k8s-id`
- Shared ACR push: `ts-sh-acr-push-id`
- Prod SWA identity: `ts-p-swa-id`

### Service Names
- Shared ACR: `tsshplatacr`
- Shared Cosmos: `tsshplatcosmos`
- Dev Key Vault: `tsdakskv`

This naming convention ensures consistency, compliance, and easy resource identification across all Transio infrastructure.