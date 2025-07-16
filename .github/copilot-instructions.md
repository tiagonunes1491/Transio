# Transio: Cloud-Native Security Showcase

## Architecture Overview

**Transio** is a dual-architecture secure secret sharing application demonstrating Azure cloud-native security patterns. It supports **two deployment models**:

1. **AKS (Kubernetes)**: Full enterprise control with Application Gateway + AKS cluster
2. **SWA + Container Apps**: Serverless with Static Web Apps + Azure Container Apps

**Core Components**:
- **Frontend**: Vanilla HTML/JS with client-side E2EE using Argon2id + AES-GCM (`src/frontend/`)
- **Backend**: Python Flask API with Fernet encryption fallback (`src/backend/app/`)
- **Storage**: Azure Cosmos DB with TTL-based auto-deletion
- **Security**: Dual encryption modes - client-side E2EE or server-side Fernet keys from Key Vault

## Critical Development Patterns

### Infrastructure as Code Structure
```
infra/
├── 0-landing-zone/      # Subscription-level foundation (identities, RBAC)
├── 10-bootstrap-kv/     # Environment Key Vault with Fernet keys
├── 20-platform-{aks,swa}/ # Core infrastructure (AKS cluster OR SWA+Container Apps)
├── 30-workload-swa/     # Application deployment layer
└── modules/             # Reusable Bicep components
```

**Key Pattern**: Infrastructure deployment follows strict sequence: landing-zone → bootstrap-kv → platform → workload. Use `scripts/build_k8s.sh` for AKS or `scripts/build_swa-aca.sh` for serverless.

### Naming Convention (CAF-Based)
**Pattern**: `{proj}-{env}-{svc}-{rtype}[-seq]`
- Project: `ts` (Transio Secrets)  
- Environment: `d`(dev), `p`(prod), `s`(staging), `sh`(shared)
- Service: `hub`, `aks`, `swa`, `plat`, `mgmt`
- Resource Type: `rg`, `kv`, `acr`, `cosmos`, `id`, etc.

**Examples**: `ts-d-aks-rg`, `tsdplatacr` (sanitized for ACR), `ts-p-plat-cosmos`

All naming logic centralized in `infra/modules/shared/naming.bicep`.

### Dual Encryption Architecture

**Client-Side E2EE** (Preferred):
```javascript
// Frontend: Argon2id key derivation + AES-GCM encryption
const { hash: key } = await argon2.hash({
  pass: passPhrase, salt, hashLen: 32, time: 2, mem: 1 << 16, // 64 MiB
  parallelism: 1, type: argon2.ArgonType.Argon2id
});
```

**Server-Side Fernet** (Fallback):
```python
# Backend: MultiFernet for key rotation support
cipher_suite = MultiFernet([Fernet(key) for key in Config.MASTER_ENCRYPTION_KEYS])
encrypted_data = cipher_suite.encrypt(secret_text.encode('utf-8'))
```

### Container & Build Patterns

**Backend** (`src/backend/`):
- Multi-stage Dockerfile with security scanning
- Poetry for dependency management (`pyproject.toml`)
- Ruff for linting with test exclusions
- Flask app with Cosmos DB integration via managed identity

**Frontend** (`src/frontend/`):
- Static files served by Nginx
- Jest testing with jsdom environment
- ESLint + Prettier for code quality
- HTML validation with html-validate

### Key Development Commands

**Local Development**:
```bash
# Full local stack with Cosmos DB emulator
docker-compose up --build -d

# Backend development
cd src/backend && python -m flask run

# Frontend testing
cd src/frontend && npm test
```

**Azure Deployment**:
```bash
# AKS deployment (enterprise)
./scripts/build_k8s.sh --env dev

# SWA deployment (serverless) 
./scripts/build_swa-aca.sh --env dev
```

**Infrastructure Management**:
```bash
# Deploy landing zone foundation
./scripts/deploy-landing-zone.sh --env dev --deployment-type aks

# Generate Fernet encryption keys in Key Vault
cd infra/30-workload-swa && ./run_secrets.sh
```

## Configuration Patterns

### Environment Variables (Backend)
```python
# config.py pattern
COSMOS_ENDPOINT = os.getenv("COSMOS_ENDPOINT")
USE_MANAGED_IDENTITY = os.getenv("USE_MANAGED_IDENTITY", "false").lower() in ("true", "1", "t")
MASTER_ENCRYPTION_KEY = os.getenv("MASTER_ENCRYPTION_KEY")  # Fernet key for fallback encryption
```

### Cosmos DB Integration
- **Connection**: Managed Identity preferred, fallback to connection strings
- **Container**: TTL configured for automatic secret deletion (24h max)
- **Models**: Pydantic-like dataclasses in `models.py` with `to_dict()` serialization

### GitHub Actions CI/CD
- **Reusable workflows**: `reusable-*.yml` for testing, scanning, building
- **Environment-specific**: Separate workflows for dev/prod + aks/swa combinations  
- **Security scans**: Trivy (containers), CodeQL (SAST), dependency checks (SCA)
- **Path-based triggers**: Only run relevant jobs when specific paths change

## Security Integration Points

1. **Azure Key Vault**: Fernet key storage and rotation
2. **Managed Identity**: Passwordless authentication throughout
3. **GitHub OIDC**: Federated identity for CI/CD (no stored secrets)
4. **Container Scanning**: Trivy integration in all container workflows
5. **RBAC**: Principle of least privilege via Bicep role assignments

## Debugging Quick Reference

- **Local Cosmos**: Access emulator at `https://localhost:8081` with self-signed cert
- **Container logs**: `docker-compose logs -f [service]`
- **Bicep validation**: Each infrastructure folder has parameter files for dev/prod
- **Frontend errors**: Check browser console for crypto API availability (HTTPS required)
- **Backend errors**: Flask debug mode enabled via `FLASK_DEBUG=True` in config
