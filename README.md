# Transio: Cloud-Native Security Showcase

[![](https://img.shields.io/github/actions/workflow/status/tiagonunes1491/Transio/ci.yml?label=CI%20%F0%9F%9A%80)](https://github.com/tiagonunes1491/Transio/actions)
[![](https://img.shields.io/badge/coverage-85%25-brightgreen)](https://tiagonunes1491.github.io/Transio/)
[![](https://img.shields.io/badge/license-MIT-blue)](https://github.com/tiagonunes1491/Transio/blob/main/LICENSE)

**Secure secret sharing with pass‑phrase end‑to‑end encryption *or* managed‑key encryption, plus self‑destructing links — purpose‑built to eliminate secret sprawl across teams and incident‑response workflows.**

Transio is a production‑grade reference application showcasing **cloud‑native security best practices** and **defense‑in‑depth** on Azure. Deploy on Azure Kubernetes Service (AKS) for full control, or go serverless with Static Web Apps (SWA) + Container Apps. Users create encrypted notes that auto‑erase after a single view.

---

## 📖 Complete Documentation

👉 **[View the full docs](https://tiagonunes1491.github.io/Transio/)** for architecture overview, security controls, problem & solution details, and roadmap.

---

## 🚀 Quick Start

Choose the deployment that fits your workload.

### 1. AKS Deployment (all‑in‑one)

```bash
# Prereqs: Azure CLI, kubectl, Helm
git clone https://github.com/tiagonunes1491/Transio.git
cd Transio
./scripts/build_k8s.sh   # Provision infra & deploy to AKS
```

### 2. Serverless Deployment (SWA + Container Apps)

```bash
# Prereq: Azure CLI
git clone https://github.com/tiagonunes1491/Transio.git
cd Transio
./scripts/build_swa-aca.sh   # Deploy front‑end to SWA, back‑end to Container Apps
```

---

## ✨ Key Features

| Category                  | Highlights                                                                                          |
| ------------------------- | --------------------------------------------------------------------------------------------------- |
| **Encryption**            | **Dual‑mode:** pass‑phrase E2EE (all crypto client‑side) *or* Fernet keys stored in Azure Key Vault |
| **Zero Residual Secrets** | One‑time links and Cosmos DB TTL ensure secrets are wiped after a single view                       |
| **Enterprise Security**   | OWASP Top 10 coverage, Trivy & CodeQL scans, 85 %+ unit‑test coverage                               |
| **Flexible Deployment**   | AKS for Kubernetes workloads • SWA + Container Apps for serverless scale                            |
| **IaC & Automation**      | Modular Bicep templates, Helm charts, GitHub Actions pipeline                                       |

### Impact Highlights

* **0 residual secrets** validated by nightly integration tests
* **< 15 min** from `git push` to production via GitHub Actions
* **99.99 %** uptime target using AZ‑replicated Cosmos DB & AKS node pools

---

## 🏗️ Deployment Options

| Option                                          | Architecture                                                  | Ideal For                                                    |
| ----------------------------------------------- | ------------------------------------------------------------- | ------------------------------------------------------------ |
| **[AKS](deployment/aks/)**                      | Kubernetes + Application Gateway                              | Enterprises needing fine‑grained control & custom networking |
| **[SWA + Container Apps](deployment/swa-aca/)** | Globally distributed static front‑end + serverless containers | Teams prioritizing minimal ops overhead                      |

Dive deeper:

* **[AKS Guide](deployment/aks/README.md)** — Bicep modules, Helm charts, CI/CD
* **[SWA + CA Guide](deployment/swa-aca/README.md)** — Fully serverless Bicep templates & best practices

---

## 🛠️ Technology Stack

| Layer           | Technologies                                 |
| --------------- | -------------------------------------------- |
| **Frontend**    | HTML5 · JavaScript · Nginx                   |
| **Backend**     | Python Flask · Azure Container Apps / AKS    |
| **Data Store**  | Azure Cosmos DB (TTL)                        |
| **IaC & CI/CD** | GitHub Actions · Bicep · Helm                |
| **Security**    | Azure Key Vault · Managed Identities · Trivy |

---

## 👤 About the Author

**Tiago Nunes** — Cloud Security Engineer who designs and delivers resilient, encrypted, and audit‑ready workloads on Azure.

> *Designed Transio to eradicate secret‑sharing risk and demonstrate scalable zero‑trust patterns.*

Connect on [LinkedIn](https://www.linkedin.com/in/tiago-nunes1491/) • Explore code on [GitHub](https://github.com/tiagonunes1491)
