# Transio: Cloud‑Native Security Showcase

**End‑to‑end encrypted secrets with one‑time, self‑destructing links**

Transio is a production‑grade app for sharing sensitive text without leaving a forensic trail. Users create encrypted notes, get a single‑use URL, and—boom—once it’s viewed, the secret is wiped forever.

This project is a live demo of **cloud‑native security best practices** and **defense‑in‑depth** on **Azure Kubernetes Service (AKS)**.

<div style="text-align: center; padding: 1rem; border: 1px solid #4CAF50; border-radius: 5px; margin-bottom: 1.5rem; background-color: #e8f5e9;"> <strong>👀 See it live! &rarr;</strong> <a href="https://transio.tiagonunes.cloud" target="_blank" rel="noopener"><strong>transio.tiagonunes.cloud</strong></a> </div>

## ✨ Key Features

<div class='feature-grid'>

<div class='feature-card'>
<h3>🔐 End‑to‑End Encryption</h3>
<p><strong>True E2EE</strong>: secrets are encrypted <em>in the browser</em> with a key derived from the user’s passphrase. No passphrase? Data still rests under a Fernet key stored in Azure Key Vault—never in code.</p>
</div>

<div class='feature-card'>
<h3>🔗 One‑Time Links</h3>
<p>Each link works exactly once. After retrieval, the record is securely deleted.</p>
</div>

<div class='feature-card'>
<h3>💥 Auto‑Destruct</h3>
<p>Unopened secrets expire after a TTL you set; opened secrets vanish instantly.</p>
</div>

<div class='feature-card'>
<h3>🛡️ Hardened Infrastructure</h3>
<p>AKS with RBAC, network policies, workload identity, and locked‑down pipelines.</p>
</div>

<div class='feature-card'>
<h3>🔍 Health Monitoring</h3>
<p>Ready / live probes and a <code>/healthz</code> endpoint for zero‑downtime rollouts.</p>
</div>

<div class='feature-card'>
<h3>🧪 Battle‑Tested</h3>
<p>85 % code coverage, 99 green tests, OWASP Top 10 checks baked in.</p>
</div>

</div>

## 🚀 Quick Start

### Prerequisites

* Azure subscription (Owner / Contributor on target RG)
* Docker + kubectl + Helm 3
* Azure CLI & Bicep

### 1. AKS Deployment

```bash
# Prereqs: Azure CLI, kubectl, Helm
git clone https://github.com/tiagonunes1491/Transio.git
cd Transio
./scripts/build_k8s.sh   # Provision infra & deploy to AKS
```

### 2. Serverless Deployment (SWA + Container Apps)

```bash
# Prereq: Azure CLI
git clone https://github.com/tiagonunes1491/Transio.git
cd Transio
./scripts/build_swa-aca.sh   # Deploy front‑end to SWA, back‑end to Container Apps
```

### Local Development

```bash
# Start all services with Docker Compose
cd deploy/compose
docker-compose up -d

# View logs (optional)
docker-compose logs -f

# Stop services when done
docker-compose down
```

## 🎬 Demo Workflow

1. **Create Secret** – write your message (optional passphrase).
2. **Generate Link** – get a unique one‑time URL.
3. **Share** – send it via your weapon of choice (Slack, smoke signal, etc.).
4. **View & Vaporise** – recipient reads it; Transio erases it.

*Demo GIF coming soon—watch this space.*

## 🎯 Project Goals

* **Prove Security Chops** – real‑world cloud security in a live AKS cluster.
* **Production‑Ready** – multi‑container app with enterprise controls.
* **Best Practices** – defense‑in‑depth, IaC, and identity‑first design.
* **Portfolio Magnet** – show why I’m the Cloud Security Engineer you need.

## 🛠️ Tech Stack

| Layer             | Technology               | Why                              |
| ----------------- | ------------------------ | -------------------------------- |
| **Frontend**      | HTML / JS / CSS + Nginx  | Lightweight, hardened container  |
| **Backend**       | Python (Flask)           | Encryption API & secret logic    |
| **DB**            | Cosmos DB                | NoSQL with TTL + global replicas |
| **Orchestration** | AKS                      | Secure, scalable containers      |
| **Secrets**       | Azure Key Vault          | HSM‑backed key storage           |
| **Registry**      | Azure Container Registry | Image scanning & CI/CD hooks     |
| **Ingress**       | App Gateway + AGIC       | L7 WAF & TLS termination         |
| **Identity**      | Azure Workload Identity  | Pod‑managed, key‑less auth       |

## 🚀 Next Steps

<div class='cta-buttons'>
<a href='problem_solution/' class='cta-button primary'>Learn More</a>
<a href='https://github.com/tiagonunes1491/Transio' class='cta-button secondary'>GitHub Repo</a>
<a href='https://www.linkedin.com/in/tiago-nunes1491/' class='cta-button secondary'>Connect on LinkedIn</a>
</div>

---

*Built by [Tiago Nunes](https://www.linkedin.com/in/tiago-nunes1491/) – Cloud Security Engineer*
