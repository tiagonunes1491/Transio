# Problem & Solution

## The Challenge — Secure, Ephemeral Information‑Sharing at Enterprise Scale

Even in zero‑trust enterprises, sensitive data still bounces around email servers, chat tools, and cloud drives.  Those artefacts linger, magnifying the blast radius of any breach and bloating compliance scope.

### Pain Points

| ⚠️ Pain                    | Why It Hurts                                                                                           |
| -------------------------- | ------------------------------------------------------------------------------------------------------ |
| **Persistent data trails** | Messages live forever in mailbox stores, ticket systems, and backups.  Hard to purge, easy to exploit. |
| **Shallow encryption**     | Many tools stop at TLS; data rests on servers in plaintext.  Violates zero‑trust assumptions.          |
| **Over‑privileged access** | “Share” often means *forever*; no automatic revocation, big insider‑risk window.                       |
| **Cumbersome PKI**         | Heavy key‑exchange workflows stall adoption, so users bypass them.                                     |

---

## The Solution — Transio’s Zero‑Knowledge Platform

Transio delivers one‑time, self‑destructing secrets with client‑side encryption, wrapped in fully automated Azure infrastructure.

### Technical Highlights

| 🚀 Capability            | How Transio Delivers                                                                |
| ------------------------ | ----------------------------------------------------------------------------------- |
| **Production AKS stack** | Modular Bicep IaC, GitHub Actions CI/CD, private networking, App Gateway + WAF.     |
| **Dual‑layer crypto**    | Browser E2EE (Argon2id + AES‑256‑GCM) or server‑side Fernet via Key Vault.          |
| **Zero persistence**     | Cosmos DB TTL + one‑time access → nothing recoverable post‑read.                    |
| **Zero‑knowledge**       | Even a full infra compromise can’t decrypt E2EE payloads.                           |
| **Cloud‑native DevOps**  | Helm charts, automated image scanning, Workload Identity (no secrets in pipelines). |

---

## Threat‑Model Snapshots

!!! danger "Advanced Persistent Threat"
Needs both Key Vault compromise **and** client passphrase to read data.

!!! warning "Insider Threat"
Admins and DBAs see only ciphertext; no privilege escalation path to clear‑text.

!!! info "Compliance"
GDPR Art 17 right‑to‑erasure honoured via TTL; strong cryptography meets PCI/HIPAA.

---

## Illustrative Code Snippets

**Client‑side E2EE**

```javascript
const { hash: key } = await argon2.hash({
  pass: passPhrase,
  salt,
  hashLen: 32,
  time: 2,
  mem: 1 << 16, // 64 MiB
  type: argon2.ArgonType.Argon2id
});
const ct = await crypto.subtle.encrypt({ name: 'AES-GCM', iv: nonce }, key, text);
```

**Server‑side MultiFernet**

```python
keys = Config.MASTER_KEYS
cipher = MultiFernet([Fernet(k) for k in keys])
enc = cipher.encrypt(secret.encode())
```

---

## Azure Reference Architecture

```mermaid
graph TD
    GA[GitHub Actions] --> ACR[Azure Container Registry]
    ACR --> AKS[AKS Cluster]
    AKS --> AGW[App Gateway + WAF]

    KV[Azure Key Vault] -->|Managed Id| AKS
    COSMOS[Cosmos DB (TTL)] -->|Private Endpoint| AKS

    LOG[Azure Monitor] --> AKS
    style KV fill:#e1f5fe
    style COSMOS fill:#ffebee
    style LOG fill:#f3e5f5
```

---

## Enterprise Impact

| Domain         | What Transio Enables                                  |
| -------------- | ----------------------------------------------------- |
| **DevOps**     | Rotate CI/CD secrets safely; share DB creds with TTL. |
| **SecOps**     | Transmit investigation notes that auto‑purge.         |
| **Compliance** | Send audit evidence, then destroy link post‑review.   |
| **Exec Comms** | Share board‑level info without digital residue.       |

---

## Skills Demonstrated

* **Azure platform engineering** – AKS, Key Vault, App Gateway, Cosmos DB, Monitor.
* **IaC mastery** – multi‑layer Bicep, environment parameterisation.
* **Secure DevOps** – GitHub Actions + Trivy + CodeQL gates.
* **Cryptographic engineering** – Argon2id, AES‑GCM, MultiFernet.
* **Zero‑trust design** – Workload Identity, private endpoints, no static creds.

---

*Transio bridges the gap between security and usability—proving that airtight, zero‑knowledge sharing can be cloud‑native, automated, and developer‑friendly.*