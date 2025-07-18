# Changelog

All notable changes to the Secure Secret Sharer project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).


## [0.6.0] - 2025-July Security Automation Enhancement

### Added
- **SWA Deployment Token Management**: Automated monthly rotation via GitHub Actions with Key Vault storage
- **Automated Rotation**: `cd-rotate-deployment-token.yml` workflow for monthly token refresh
- **Credential Management**: SWA deployment tokens stored securely in Azure Key Vault
- **Federated Identity**: Separate service principals for token generation and Key Vault access
- **Audit Trail**: Complete logging of token rotation events via Azure Key Vault logs

### Security
- **Token Rotation**: Automated SWA deployment token rotation on 1st day of every month
- **Security Automation**: Monthly credential rotation with audit trails
- **Enhanced Documentation**: Comprehensive documentation of token management workflows

---

## [0.5.0] - 2025-July Foundation Release

### Added
- **Live Demo**: 24x7 accessible demonstration environment
- **Core Features**: Ephemeral secret sharing with one-time URLs and configurable TTL
- **Security**: End-to-end encryption (Fernet), Azure Key Vault integration, TLS 1.3
- **Frontend**: Responsive web interface with real-time secret creation/sharing
- **Backend**: RESTful Flask API with health checks and structured logging
- **Database**: Azure Cosmos DB with automatic TTL cleanup and encrypted storage

### Infrastructure
- **Deployment**: AKS or Static Web Apps + Container Apps with Bicep IaC
- **Security**: Application Gateway with WAF, private networking, Workload Identity
- **DevOps**: GitHub Actions CI/CD with security scanning (Trivy, CodeQL)

### Quality & Monitoring
- **Testing**: 99 backend tests with 85%+ coverage, OWASP Top 10 compliance
- **Observability**: Kubernetes probes, performance monitoring, security logging
- **Documentation**: MkDocs site with architecture guides and security documentation

---

