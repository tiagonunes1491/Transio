# Transio: Cloud-Native Security Showcase

**Secure secret sharing with end-to-end encryption and self-destructing links**

Transio is a production-grade application designed for sharing sensitive text-based information securely. Users can create self-destructing, encrypted notes that are accessible via a unique one-time link. Once viewed, the secret is permanently deleted.

This project serves as a comprehensive demonstration of **cloud-native security best practices** and **defense-in-depth strategies** deployed on **Azure Kubernetes Service (AKS)**.

## ✨ Key Features

<div class="feature-grid">
<div class="feature-card">
<h3>🔐 End-to-End Encryption</h3>
<p>Secrets are encrypted at rest (in the database) and in transit (via HTTPS). Uses master encryption key (Fernet) stored in Azure Key Vault for cryptographic operations.</p>
</div>

<div class="feature-card">
<h3>🔗 One-Time Access Links</h3>
<p>Generated links are valid for a single view only. Once a secret is retrieved, it's permanently deleted from the database.</p>
</div>

<div class="feature-card">
<h3>💥 Self-Destructing Secrets</h3>
<p>Secrets are automatically purged after being viewed or after an expiry period if unaccessed.</p>
</div>

<div class="feature-card">
<h3>🛡️ Secure Infrastructure</h3>
<p>Deployed on Azure Kubernetes Service with security best practices, RBAC, network policies, and workload identity.</p>
</div>

<div class="feature-card">
<h3>🔍 Health Monitoring</h3>
<p>Comprehensive health check endpoints for monitoring application status and availability.</p>
</div>

<div class="feature-card">
<h3>🧪 Thoroughly Tested</h3>
<p>85% test coverage with 99 passing tests, comprehensive security validation, and OWASP Top 10 compliance.</p>
</div>
</div>

## 🚀 Quick Start

### Prerequisites
- Azure subscription with appropriate permissions
- Docker and Kubernetes tools
- Helm 3.x

### Deploy with Scripts

```bash
# Clone the repository
git clone https://github.com/tiagonunes1491/Transio.git
cd Transio

# Deploy Azure infrastructure and application
./scripts/deploy-landing-zone.sh
./build_dev.sh
```

### Manual Deployment

```bash
# Build and push container images
docker build -t your-registry/transio-frontend:latest ./src/frontend
docker build -t your-registry/transio-backend:latest ./src/backend
docker push your-registry/transio-frontend:latest
docker push your-registry/transio-backend:latest

# Deploy with Helm
helm upgrade --install transio ./deploy/helm-chart \
  --set frontend.image.repository=your-registry/transio-frontend \
  --set backend.image.repository=your-registry/transio-backend
```

### Local Development

```bash
# Start backend services
cd src/backend
pip install -r requirements.txt
python app.py

# Serve frontend (in another terminal)
cd src/frontend/static
python -m http.server 8080
```

!!! tip "Development Environment"
    For detailed technical instructions on setting up the Azure environment, building images, and deploying the application using Helm, refer to the `DEPLOYMENT.md` guide.

## 🎬 Demo

The application flow includes:

1. **Create Secret**: User composes a sensitive message with optional passphrase protection
2. **Generate Link**: System creates a unique, one-time access URL
3. **Share Securely**: Link can be shared via any communication channel
4. **View Once**: Secret is displayed and immediately deleted from the system

*Demo GIF coming soon - showing the complete workflow of creating, sharing, and viewing self-destructing secrets.*

## 🎯 Project Goals

The primary objectives of this project are:

- **Demonstrate Security Expertise**: Showcase practical application of cloud security principles in a Kubernetes environment
- **Production-Ready Implementation**: Deploy secure multi-container applications with enterprise-grade security controls
- **Best Practices**: Implement defense-in-depth strategies, secure infrastructure provisioning, and identity management
- **Portfolio Showcase**: Highlight skills relevant to Cloud Security Engineer roles

## 🛠️ Technology Stack

| Component | Technology | Purpose |
|-----------|------------|---------|
| **Frontend** | HTML/JavaScript/CSS + Nginx | Static web interface with hardened container |
| **Backend** | Python (Flask) | API for encryption, decryption, and secret management |
| **Database** | PostgreSQL | Encrypted secret storage with role-based access |
| **Orchestration** | Azure Kubernetes Service (AKS) | Container hosting with security best practices |
| **Secrets Management** | Azure Key Vault | Secure storage for encryption keys and credentials |
| **Registry** | Azure Container Registry (ACR) | Vulnerability-scanned container images |
| **Ingress** | Azure Application Gateway + AGIC | L7 load balancing and secure ingress |
| **Identity** | Azure Workload Identity | Credential-less access to Azure resources |

## 🚀 Get Started

<div class="cta-buttons">
<a href="problem_solution/" class="cta-button primary">Learn More</a>
<a href="https://github.com/tiagonunes1491/Transio" class="cta-button secondary">View on GitHub</a>
<a href="https://www.linkedin.com/in/tiago-nunes1491/" class="cta-button secondary">Contact Author</a>
</div>

---

*Built by [Tiago Nunes](https://www.linkedin.com/in/tiago-nunes1491/) - Cloud Security Engineer*