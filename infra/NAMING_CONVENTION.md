# SecureSharer Infrastructure Naming Convention

This document describes the standardized naming convention implemented across all SecureSharer infrastructure, based on Cloud Adoption Framework (CAF) standards.

## Naming Pattern

All Azure resources follow the pattern: `{proj}-{env}-{svc}-{rtype}{-seq}`

### Components

| Component | Description | Example | Rules |
|-----------|-------------|---------|-------|
| **proj** | Project code (2-3 letters) | `ss` | Lowercase letters only, `^[a-z]{2,3}$` |
| **env** | Environment code | `d`, `s`, `p`, `sh` | dev→d, staging→s, prod→p, shared→sh |
| **svc** | Service code (2-4 letters) | `hub`, `aks`, `swa`, `plat` | Lowercase letters only, `^[a-z]{2,4}$` |
| **rtype** | Resource type code | `rg`, `acr`, `cosmos`, `id` | CAF standard abbreviations |
| **seq** | Optional sequence (01-99) | `01`, `02` | Two digits, optional |

### Resource Type Codes

| Azure Resource | Code | Example Name |
|---------------|------|--------------|
| Resource Group | `rg` | `ss-d-aks-rg` |
| Container Registry | `acr` | `ssshplatacr` (sanitized) |
| Cosmos DB | `cosmos` | `ssshplatcosmos` (sanitized) |
| Key Vault | `kv` | `ssdakskv` (sanitized) |
| Log Analytics | `log` | `ss-sh-hub-log` |
| Static Web App | `swa` | `ss-d-swa-swa` |
| Container App Environment | `cae` | `ss-d-swa-cae` |
| Container App | `ca` | `ss-d-swa-ca` |
| User Assigned Managed Identity | `id` | `ss-d-k8s-id` |
| Virtual Network | `vnet` | `ss-d-hub-vnet` |
| Private Endpoint | `pe` | `ss-d-aks-pe` |
| Subnet | `sub` | `ss-d-aks-sub` |

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
| `project` | Project code | `^[a-z]{2,3}$` | `ss` |
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
    projectCode: 'ss'
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
    project: 'ss'
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
- Shared hub: `ss-sh-hub-rg`
- Dev AKS: `ss-d-aks-rg`
- Prod SWA: `ss-p-swa-rg`
- Management: `ss-d-mgmt-rg`

### Identity Names
- Dev K8s identity: `ss-d-k8s-id`
- Shared ACR push: `ss-sh-acr-push-id`
- Prod SWA identity: `ss-p-swa-id`

### Service Names
- Shared ACR: `ssshplatacr`
- Shared Cosmos: `ssshplatcosmos`
- Dev Key Vault: `ssdakskv`

This naming convention ensures consistency, compliance, and easy resource identification across all SecureSharer infrastructure.