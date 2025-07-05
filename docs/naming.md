Context
I have Bicep templates that deploy Transio resources.

Enforced conventions
Naming pattern (all lower-case, hyphen-separated)

bash
Copy
Edit
<prefix>-<env>-<flavour>-<service>-<seq?>
  prefix   = ts                       # project code
  env      = dev | prod | shr         # shr = shared hub  (later: qa, sbx…)
  flavour  = aks | swa | shared       # shared = cross-env services
  service  = rg | acr | cdb | db | vnet | aks | swa | aca | kv | log
  seq      = 01, 02…  (omit if single instance)
Required tags on every resource

Project	Environment	Flavour	CostCenter	Owner	DataClass	Deployment
Transio	dev / prod / shr	aks / swa / shared	R&D	tiago.nunes	Confidential	<pipeline-run-id>

Your tasks

Parse the Bicep file(s) provided.

For each resource:
• verify the name matches the pattern above.
• verify the tags block contains every required key with some value.

Output a Markdown table: ResourceType · CurrentName · Status (✔ / ✘) · If ✘ → SuggestedName / MissingTags.

If any resource fails, also generate an auto-fixed version of the affected resource block(s) in a code block.

Input: the Bicep code (one or many files).
Output: the review table + corrected snippets (no extra commentary).

Begin review.

--


Below is a **single, opinionated convention** you can drop into the repo and reference in every Bicep file and README. It balances Azure’s length limits, human readability, and automated enforcement.

---

## 1 Resource-name pattern

```
<prefix>-<env>-<flavour>-<service>-<seq>
```

| Segment     | Example                                                      | Rules & Rationale                                                                                                 |
| ----------- | ------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------- |
| **prefix**  | **`ts`**                                                     | Short, unique project code (Transio). Keeps names unique across tenants.                                    |
| **env**     | `dev` \| `prod`                                              | Lower-case, three-letter environment codes. Extendable (`qa`, `sbx`).                                             |
| **flavour** | `shared` \| `aks` \| `swa`                                   | Identifies the platform flavour that “owns” the resource.<br>For flavour-agnostic hub resources use **`shared`**. |
| **service** | `rg`, `acr`, `cdb`, `vnet`, `aks`, `swa`, `aca`, `kv`, `log` | Azure-approved two- to four-letter abbreviations (see cheat-sheet below).                                         |
| **seq**     | `01`, `02` (optional)                                        | Only when you legitimately need multiple of the same type in one scope.                                           |

### Cheat-sheet (service abbreviations)

| Resource            | Abbrev | Example name         |
| ------------------- | ------ | -------------------- |
| Resource Group      | `rg`   | `ts-prod-shared-rg`  |
| Azure Container Reg | `acr`  | `ts-prod-shared-acr` |
| Cosmos DB account   | `cdb`  | `ts-prod-shared-cdb` |
| Cosmos database     | `db`   | `ts-prod-swa-db`     |
| AKS cluster         | `aks`  | `ts-prod-aks-aks`    |
| Static Web App      | `swa`  | `ts-prod-swa-swa`    |
| Container App env   | `aca`  | `ts-prod-swa-aca`    |
| Key Vault           | `kv`   | `ts-prod-shared-kv`  |
| Log Analytics       | `log`  | `ss-prod-shared-log` |

> **Length guard:** This pattern tops out at \~40 chars (well under the 64-char Cosmos & 80-char Storage limits).

---

## 2 Tag schema (applied to *every* resource)

| Tag Key (PascalCase) | Value example              | Why                                          |
| -------------------- | -------------------------- | -------------------------------------------- |
| `Project`            | `Transio`             | Portfolio grouping across tenants.           |
| `Environment`        | `dev` / `prod`             | Filter cost & alerts easily.                 |
| `Flavour`            | `aks` / `swa` / `shared`   | Maps to landing-zone folders.                |
| `CostCenter`         | `R&D`                      | Required by most FinOps teams—even if dummy. |
| `Owner`              | `tiago.nunes`              | Human accountable.                           |
| `Contact`            | `slack:#transio`      | Ops escalation path.                         |
| `DataClass`          | `Confidential`             | Quick compliance filter.                     |
| `Deployment`         | Git SHA or pipeline run-id | Trace resource to pipeline artefact.         |
| `Expires` (optional) | `2025-12-31`               | Auto-clean lab resources with tag policy.    |

### Implementation hints

1. **Bicep param**

   ```bicep
   @allowed([
     'dev'
     'prod'
   ])
   param env string
   var defaultTags = {
     Project:       'SecureSharer'
     Environment:   env
     Flavour:       flavour
     Owner:         owner
     CostCenter:    'R&D'
     DataClass:     'Confidential'
     Deployment:    deployment().name
   }
   ```

   Then add `tags: defaultTags` to every `resource` block or module.

2. **Azure Policy (lz-shared)**
   *Policy set:* **“Require tags and their default values”** for the above keys, plus **“Append”** policy to add `Deployment` automatically.
   Scope it to the management-group so all subs inherit it.

3. **Pipeline guard**
   Fail CI if any `what-if` output reports `"tags": null`.

---

## 3 Folder mapping with the new naming

| Folder                | Typical RG name            | Cosmos database                  |
| --------------------- | -------------------------- | -------------------------------- |
| `10-lz-shared`        | `ss-prod-shared-rg`        | *(n/a)*                          |
| `20-platform-shared`  | `ss-prod-shared-rg` (same) | `ss-prod-shared-cdb` *(account)* |
| `30-platform-aks`     | `ss-prod-aks-rg`           | `ss-prod-aks-db`                 |
| `30-platform-swa-aca` | `ss-prod-swa-rg`           | `ss-prod-swa-db`                 |

---

## 4 What reviewers will like

* **Consistency:** every name and tag telegraphs env/flavour at a glance.
* **Policy-ready:** enforced keys mean zero drift.
* **Searchable:** `az resource list --tag Flavour=aks` instantly filters your AKS estate.
* **Cost clarity:** CostCenter + Flavour make charge-back (or a cost chart in README) trivial.

Adopt this pattern across your Bicep modules (`40-modules/core/naming.bicep`), reference the default tag object in each template, and your repository will look disciplined and enterprise-ready.
