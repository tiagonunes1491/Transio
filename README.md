# Transio: Cloud-Native Security Showcase

**Secure secret sharing with end-to-end encryption and self-destructing links**

Transio is a production-grade application demonstrating **cloud-native security best practices** and **defense-in-depth strategies** on Azure Kubernetes Service. Users can create self-destructing, encrypted notes accessible via unique one-time links.

## 📖 Complete Documentation

**👉 [Visit the full documentation site](https://tiagonunes1491.github.io/Transio/)**

The comprehensive documentation includes:
- **[Architecture Overview](https://tiagonunes1491.github.io/Transio/architecture/)** - System design and technical implementation
- **[Security Controls](https://tiagonunes1491.github.io/Transio/security/)** - OWASP compliance and security measures  
- **[Problem & Solution](https://tiagonunes1491.github.io/Transio/problem_solution/)** - Use cases and security benefits
- **[Roadmap](https://tiagonunes1491.github.io/Transio/roadmap/)** - Future enhancements and development plans

## 🚀 Quick Start

```bash
# Clone and deploy
git clone https://github.com/tiagonunes1491/Transio.git
cd Transio
./scripts/deploy-landing-zone.sh
./build_dev.sh
```

## ✨ Key Features

- 🔐 **End-to-End Encryption** - Fernet encryption with Azure Key Vault
- 🔗 **One-Time Links** - Self-destructing secrets after single view  
- 🛡️ **Enterprise Security** - OWASP Top 10 compliance, 85% test coverage
- ☁️ **Cloud-Native** - Azure Kubernetes Service with Workload Identity

## 🛠️ Technology Stack

| Layer | Technology |
|-------|------------|
| **Frontend** | HTML/JavaScript + Nginx |
| **Backend** | Python Flask + PostgreSQL |
| **Infrastructure** | Azure Kubernetes Service |
| **Security** | Azure Key Vault + Workload Identity |

## 👨‍💻 Author

**Tiago Nunes** - Cloud Security Engineer  
📧 [LinkedIn](https://www.linkedin.com/in/tiago-nunes1491/) | 🔗 [GitHub](https://github.com/tiagonunes1491)

---

*For complete technical details, architecture diagrams, security analysis, and deployment guides, visit the [documentation site](https://tiagonunes1491.github.io/Transio/).*