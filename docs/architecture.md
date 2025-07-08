# Architecture Overview

## System Architecture

Transio follows a **tiered, cloud-native architecture** designed for security, scalability, and operational excellence on Azure Kubernetes Service.

```mermaid
graph TB
    subgraph "Internet"
        U[Users]
    end
    
    subgraph "Azure Application Gateway"
        AG[Application Gateway<br/>+ WAF + TLS]
    end
    
    subgraph "Azure Kubernetes Service (AKS)"
        subgraph "Ingress Layer"
            AGIC[AGIC Controller]
        end
        
        subgraph "Application Pods"
            FE[Frontend<br/>Nginx + Static Files]
            BE[Backend<br/>Flask API]
        end
        
        subgraph "Data Layer"
            DB[(PostgreSQL<br/>Encrypted Storage)]
        end
        
        subgraph "Security"
            WI[Workload Identity]
            CSI[CSI Secret Store]
        end
    end
    
    subgraph "Azure Services"
        KV[Azure Key Vault<br/>Master Encryption Keys]
        ACR[Azure Container Registry<br/>Vulnerability Scanned Images]
        RBAC[Azure RBAC<br/>Identity & Access]
    end
    
    U --> AG
    AG --> AGIC
    AGIC --> FE
    FE --> BE
    BE --> DB
    
    WI --> KV
    CSI --> KV
    BE --> CSI
    
    AGIC -.-> ACR
    FE -.-> ACR
    BE -.-> ACR
    
    WI -.-> RBAC
    
    style AG fill:#e3f2fd
    style KV fill:#e8f5e8
    style DB fill:#fff3e0
    style WI fill:#f3e5f5
```

## Component Details

### Frontend Layer
**Technology**: Nginx 1.28 Alpine + Static HTML/JavaScript/CSS

- **Hardened Container**: Non-root user, minimal attack surface
- **Static Content**: HTML, CSS, JavaScript for user interface
- **Client-Side Crypto**: Argon2 for client-side key derivation
- **Security Headers**: CSP, HSTS, X-Frame-Options configured

```yaml
# Frontend Security Configuration
securityContext:
  runAsNonRoot: true
  runAsUser: 101
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
```

### Backend API
**Technology**: Python 3.11 + Flask + Gunicorn

- **RESTful API**: Clean endpoints for secret management
- **Encryption Engine**: Fernet symmetric encryption with Key Vault integration
- **Input Validation**: Comprehensive validation and sanitization
- **Health Checks**: Kubernetes-native liveness and readiness probes

#### Key Endpoints
| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/secrets` | POST | Create new encrypted secret |
| `/api/secrets/<id>` | GET | Retrieve and delete secret |
| `/api/health` | GET | Application health status |
| `/api/ready` | GET | Readiness probe for Kubernetes |

### Database Layer
**Technology**: PostgreSQL 15 with encrypted storage

- **Schema Design**: Optimized for secret storage and automatic cleanup
- **Encryption at Rest**: Azure disk encryption + application-level encryption
- **Access Control**: Dedicated service accounts with minimal privileges
- **Backup Strategy**: Point-in-time recovery with encrypted backups

```sql
-- Core secret storage schema
CREATE TABLE secrets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    encrypted_content TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP NOT NULL,
    viewed BOOLEAN DEFAULT FALSE
);
```

## Cryptographic Flow

The encryption and decryption process ensures end-to-end security:

```mermaid
sequenceDiagram
    participant U as User
    participant F as Frontend
    participant B as Backend
    participant KV as Key Vault
    participant DB as Database

    Note over U,DB: Secret Creation Flow
    U->>F: Submit secret text
    F->>B: POST /api/secrets
    B->>KV: Retrieve master key
    KV-->>B: Return encryption key
    B->>B: Encrypt with Fernet
    B->>DB: Store encrypted secret
    DB-->>B: Return secret ID
    B-->>F: Return access link
    F-->>U: Display sharing link

    Note over U,DB: Secret Retrieval Flow
    U->>F: Access secret link
    F->>B: GET /api/secrets/{id}
    B->>DB: Query secret
    DB-->>B: Return encrypted data
    B->>KV: Retrieve master key
    KV-->>B: Return decryption key
    B->>B: Decrypt content
    B->>DB: DELETE secret
    B-->>F: Return plaintext
    F-->>U: Display secret
```

## Security Architecture

### Identity and Access Management

**Azure Workload Identity** provides credential-less access to Azure resources:

```yaml
# Workload Identity Configuration
apiVersion: v1
kind: ServiceAccount
metadata:
  name: transio-backend
  annotations:
    azure.workload.identity/client-id: "12345678-1234-1234-1234-123456789012"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: transio-backend
spec:
  template:
    metadata:
      labels:
        azure.workload.identity/use: "true"
    spec:
      serviceAccountName: transio-backend
```

### Network Security

**Defense in Depth** with multiple security layers:

- **Azure Application Gateway**: L7 load balancing, WAF protection, TLS termination
- **Network Policies**: Kubernetes-native traffic segmentation
- **Service Mesh** (Future): mTLS for pod-to-pod communication
- **Private Endpoints**: Secure connectivity to Azure services

### Secret Management

**Azure Key Vault Integration** via CSI Secret Store:

```yaml
# Secret Store CSI Driver Configuration
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: transio-secrets
spec:
  provider: azure
  parameters:
    keyvaultName: "transio-kv-dev"
    cloudName: ""
    objects: |
      array:
        - objectName: "encryption-key"
          objectType: "secret"
```

## Deployment Architecture

### Infrastructure as Code

**Bicep Templates** for reproducible infrastructure:

```
infra/
├── 0-landing-zone/     # Foundational identities and RBAC
├── 10-bootstrap-kv/    # Key Vault and secrets
├── 20-platform-aks/   # AKS cluster configuration
└── 30-workload-swa/   # Alternative SWA deployment
```

### CI/CD Pipeline

**GitHub Actions** with security scanning:

1. **Source Control**: Branch protection, signed commits
2. **Build Stage**: Container image creation and scanning
3. **Security Scanning**: SAST, dependency scanning, container vulnerabilities
4. **Deployment**: Helm charts with environment promotion
5. **Monitoring**: Health checks and observability

```yaml
# CI/CD Security Gates
- name: Container Security Scan
  uses: ./.github/workflows/reusable-container-scan.yml
- name: SAST Analysis
  uses: ./.github/workflows/reusable-sast-scan.yml
- name: Dependency Check
  uses: ./.github/workflows/reusable-sca-scan.yml
```

## Performance & Scalability

### Horizontal Pod Autoscaling

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: transio-backend-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: transio-backend
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

### Resource Management

| Component | CPU Request | Memory Request | CPU Limit | Memory Limit |
|-----------|-------------|----------------|-----------|--------------|
| Frontend | 100m | 128Mi | 200m | 256Mi |
| Backend | 200m | 256Mi | 500m | 512Mi |
| Database | 500m | 1Gi | 1000m | 2Gi |

## Disaster Recovery

### Backup Strategy
- **Database**: Automated daily backups with 30-day retention
- **Configuration**: GitOps with Infrastructure as Code
- **Secrets**: Azure Key Vault geo-replication
- **Container Images**: ACR geo-replication

### High Availability
- **Multi-AZ Deployment**: Pods distributed across availability zones
- **Database Clustering**: PostgreSQL with read replicas
- **Load Balancing**: Azure Application Gateway with health probes
- **Circuit Breakers**: Resilient API communication patterns

---

*Next: Explore the comprehensive [security controls](security.md) implemented in Transio.*