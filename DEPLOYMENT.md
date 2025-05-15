# Secure Secret Sharer - Detailed Deployment Guide

This document provides comprehensive technical instructions for setting up and deploying the "Secure Secret Sharer" application on Azure Kubernetes Service (AKS).

## Prerequisites

Before you begin, ensure you have the following installed and configured:

* Azure CLI: Logged in (`az login`) and set to the correct subscription (`az account set --subscription "<Your-Subscription>"`).
* `kubectl`: Configured to interact with Kubernetes clusters.
* Helm (v3+): For deploying the application chart.
* Docker Desktop (or Docker CLI): For building and pushing container images.
* A local copy of this project repository.
* Sufficient permissions in your Azure subscription to create and manage resources (Resource Groups, ACR, AKV, UAMIs, AKS, Application Gateway, Role Assignments).

## 1. Azure Resource Provisioning

Create all resources in the same Azure region (e.g., `Spain Central`) for optimal performance and to simplify networking.

### a. Resource Group

* Create a new resource group to hold all project resources.
  * **Name:** `rg-secure-secret-sharer-mvp`
  * **Region:** e.g., `Spain Central`

### b. Azure Container Registry (ACR)

* Create an ACR instance to store your Docker images.
  * **Name:** `acrsecuresecsharer` (globally unique)
  * **Resource Group:** `rg-secure-secret-sharer-mvp`
  * **SKU:** Basic (sufficient for MVP)
  * **Admin user:** Can be left disabled.

### c. Azure Key Vault (AKV)

* Create a Key Vault to store secrets.
  * **Name:** `kv-secure-secret-sharer` (globally unique)
  * **Resource Group:** `rg-secure-secret-sharer-mvp`
  * **Region:** Same as above.
  * **Pricing tier:** Standard.
  * **Recovery options:** Enable "Soft delete" (default) and **"Purge protection"**.
  * **Access configuration:** Select permission model: **"Azure role-based access control"**.
* **Create Secrets in AKV:**
  Navigate to your Key Vault -> Secrets -> "+ Generate/Import". Create the following secrets:
  1. **Name:** `postgres-password`
     * **Value:** A strong, generated password for the PostgreSQL initial admin user.
  2. **Name:** `app-db-user`
     * **Value:** The actual username string for your application's database user (e.g., `secret_sharer_app_user`).
  3. **Name:** `app-db-password`
     * **Value:** A strong, generated password for the `app-db-user`.
  4. **Name:** `app-master-encryption-key`
     * **Value:** A Fernet key (generate using `python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"`).

### d. User Assigned Managed Identities (UAMIs)

Create two UAMIs in your resource group (`rg-secure-secret-sharer-mvp`):

1. **Backend UAMI:**
   * **Name:** `id-secretsharer-backend`
   * **Note down its Client ID and Principal ID.** (Example Client ID: `fa376030-252d-443f-a32d-294e3cda90e1`)
2. **Database Initialization UAMI:**
   * **Name:** `id-secret-sharer-db-init`
   * **Note down its Client ID and Principal ID.** (Example Client ID: `ef9e4258-98dc-49a8-804b-dfe502309386`)

### e. Granting UAMI Permissions to AKV

For your Key Vault (`kv-secure-secret-sharer`):

1. Go to "Access control (IAM)".
2. Add role assignment:
   * **Role:** "Key Vault Secrets User"
   * **Assign access to:** Managed identity
   * **Members:** Select `id-secretsharer-backend`.
3. Repeat "Add role assignment":
   * **Role:** "Key Vault Secrets User"
   * **Assign access to:** Managed identity
   * **Members:** Select `id-secret-sharer-db-init`.

### f. Azure Kubernetes Service (AKS) Cluster

* Create an AKS cluster.
  * **Resource Group:** `rg-secure-secret-sharer-mvp`
  * **Cluster name:** `aks-securesharer-mvp`
  * **Region:** `Spain Central`
  * **Kubernetes version:** A recent stable version (e.g., 1.28+).
  * **Node pools:** A single pool with 1-2 nodes of a general-purpose size (e.g., `Standard_DS2_v2`) is fine for MVP.
  * **Networking:**
      * Network configuration: **Azure CNI**.
      * Network policy: **Azure**.
  * **Integrations:**
      * Enable **Azure Key Vault Secrets Provider** (Secrets Store CSI Driver add-on).
  * **Advanced / Security / Identity:**
      * Ensure **OIDC Issuer** is **Enabled**.
      * Ensure **Workload Identity** is **Enabled**.
* **Get AKS OIDC Issuer URL:** After creation, go to AKS Cluster -> Settings -> Properties. Note down the **"OIDC issuer URL"**.
  * (Example: `https://<region>.oic.prod-aks.azure.com/<YOUR_TENANT_ID>/<YOUR_AKS_OIDC_ID>/`)

### g. Azure Application Gateway (AppGW)

* Create an Azure Application Gateway.
  * **Resource Group:** `rg-secure-secret-sharer-mvp`
  * **Application gateway name:** `appgw-secretsharer`
  * **Region:** `Spain Central`
  * **Tier:** **Standard V2** (or WAF V2).
  * **Enable autoscaling:** Yes (e.g., Min 1, Max 2 instances).
  * **HTTP2:** Enabled.
  * **Virtual network:** Select the VNet used by your AKS cluster (typically in the `MC_...` resource group, e.g., `aks-vnet-...`).
  * **Subnet:** Create a **new, dedicated subnet** for the Application Gateway within the AKS VNet (e.g., `snet-appgateway` with an address range like `10.225.0.0/24` that doesn't overlap with AKS node subnets).
  * **Frontends:** Create a new **Public** Frontend IP configuration with a new static Public IP address (e.g., `pip-appgw-secretsharer`). Note this IP.
  * **Backends:** Add a dummy backend pool (e.g., `dummy-initial-backendpool`, add without targets).
  * **Configuration (Routing Rule):** Add an initial routing rule (`initial-http-rule`) with a listener (`initial-http-listener`) for HTTP on port 80 using the public frontend IP, targeting the dummy backend pool with a basic HTTP setting (port 80). AGIC will manage these dynamically later.
  * Create the Application Gateway (this can take 15-30+ minutes).

### h. Enabling AGIC Add-on in AKS

1. Register the `AppGatewayWithOverlayPreview` feature flag if using Azure CNI Overlay:
   ```bash
   az feature register --namespace Microsoft.ContainerService --name AppGatewayWithOverlayPreview
   # Wait for it to become "Registered"
   az feature show --namespace Microsoft.ContainerService --name AppGatewayWithOverlayPreview --query "properties.state"
   az provider register --namespace Microsoft.ContainerService
   ```
2. Enable the AGIC add-on using Azure CLI:
   ```bash
   APP_GW_ID=$(az network application-gateway show --name appgw-secretsharer --resource-group rg-secure-secret-sharer-mvp --query id --output tsv)
   az aks enable-addons \
       --addons ingress-appgw \
       --name aks-securesharer-mvp \
       --resource-group rg-secure-secret-sharer-mvp \
       --appgw-id "${APP_GW_ID}"
   ```
3. Verify AGIC pods are running in `kube-system`: `kubectl get pods -n kube-system -l app=ingress-appgw`

### i. Configuring Federated Identity Credentials on UAMIs

For each UAMI, add a federated credential in the Azure Portal (Managed Identity -> Select UAMI -> Federated credentials -> + Add credential):

* **Scenario:** Kubernetes accessing Azure resources.
* **1. For `id-secretsharer-backend` UAMI:**
    * **Cluster Issuer URL:** Your AKS OIDC Issuer URL.
    * **Namespace:** `default` (or your target deployment namespace).
    * **Service account name:** `secret-sharer-backend-sa`.
    * **Credential name:** e.g., `aks-backend-sa-federation`.
* **2. For `id-secret-sharer-db-init` UAMI:**
    * **Cluster Issuer URL:** Your AKS OIDC Issuer URL.
    * **Namespace:** `default` (or your target deployment namespace).
    * **Service account name:** `secret-sharer-db-init-sa`.
    * **Credential name:** e.g., `aks-dbinit-sa-federation`.

## 2. Preparing Application Images

### Security Hardening for Container Images

1. **Ensure Dockerfiles are Secure:**
   * Use multi-stage builds.
   * Run containers as non-root users.
   * Minimize layers and use minimal base images (e.g., Alpine).

2. **Build Docker Images:**
   Navigate to your `frontend` and `backend` code directories and build the images.
   ```bash
   # In frontend directory (replace with your actual tag)
   docker build -t acrsecuresecsharer.azurecr.io/secure-secret-sharer-frontend:0.3.0 . 
   # In backend directory (replace with your actual tag)
   docker build -t acrsecuresecsharer.azurecr.io/secure-secret-sharer-backend:0.3.0 .
   ```
   *(Adjust tags to match your latest working versions.)*

3. **Push Images to ACR:**
   ```bash
   az acr login --name acrsecuresecsharer
   docker push acrsecuresecsharer.azurecr.io/secure-secret-sharer-frontend:<your-tag>
   docker push acrsecuresecsharer.azurecr.io/secure-secret-sharer-backend:<your-tag>
   ```

4. **Ensure AKS can pull from ACR:**
   ```bash
   az aks update --name aks-securesharer-mvp --resource-group rg-secure-secret-sharer-mvp --attach-acr acrsecuresecsharer
   ```

### Container Security Scanning with Trivy

Implement comprehensive vulnerability scanning using Trivy as part of your container security strategy:

1. **Install Trivy:**
   ```bash
   # For Windows with PowerShell (using Chocolatey):
   choco install trivy -y
   
   # For Linux:
   curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
   ```

2. **Scan Images:**
   ```bash
   # Set to fail on HIGH and CRITICAL vulnerabilities
   trivy image --severity HIGH,CRITICAL acrsecuresecsharer.azurecr.io/secure-secret-sharer-frontend:0.3.0
   trivy image --severity HIGH,CRITICAL acrsecuresecsharer.azurecr.io/secure-secret-sharer-backend:0.3.0
   ```

3. **Generate Comprehensive Reports:**
   ```bash
   # Generate detailed HTML reports for documentation/audit
   trivy image --format template --template "@html.tpl" -o frontend-scan.html acrsecuresecsharer.azurecr.io/secure-secret-sharer-frontend:0.3.0
   trivy image --format template --template "@html.tpl" -o backend-scan.html acrsecuresecsharer.azurecr.io/secure-secret-sharer-backend:0.3.0
   
   # Generate JSON reports for pipeline integration
   trivy image --format json -o frontend-scan.json acrsecuresecsharer.azurecr.io/secure-secret-sharer-frontend:0.3.0
   trivy image --format json -o backend-scan.json acrsecuresecsharer.azurecr.io/secure-secret-sharer-backend:0.3.0
   ```

4. **Scan Results Summary (as of May 15, 2025):**
   * **Frontend Image (`acrsecuresecsharer.azurecr.io/secure-secret-sharer-frontend:0.3.0`):** 
     * 2 HIGH vulnerabilities in `libxml2` (CVE-2025-32414, CVE-2025-32415), fixed in `2.13.4-r6`.
   * **Backend Image (`acrsecuresecsharer.azurecr.io/secure-secret-sharer-backend:0.3.0`):** 
     * No HIGH or CRITICAL vulnerabilities identified.

5. **Remediation Strategy:**
   * For the frontend image, update the base image or specifically update the `libxml2` package:
     ```dockerfile
     # In the Dockerfile, add:
     RUN apk update && apk upgrade libxml2>=2.13.4-r6
     ```
   * Rebuild and rescan the image to verify the vulnerabilities are resolved.

## 3. Helm Chart Deployment

1. **Navigate to Helm Chart Directory:**
   Ensure you are in the directory containing `Chart.yaml` (e.g., `k8s/secret-sharer-app/`).

2. **Update `values.yaml`:**
   Edit `values.yaml` to reflect your Azure environment and image tags:
   * `backend.image.repository` and `frontend.image.repository`.
   * `backend.image.tag` and `frontend.image.tag` (e.g., `"0.3.0"`).
   * `backend.keyVault.name`: `"kv-secure-secret-sharer"`.
   * `backend.keyVault.tenantId`: Your Azure Tenant ID.
   * `backend.keyVault.userAssignedIdentityClientID`: Client ID of `id-secretsharer-backend`.
   * `database.serviceAccount.azureClientId`: Client ID of `id-secret-sharer-db-init`.
   * `ingress.enabled`: `true`.
   * `ingress.className`: `"azure/application-gateway"`.
   * `ingress.hosts[0].host`: Your desired public hostname (e.g., `secretsharer.example.com`).
   * Ensure other values (ports, AKV secret names for `dbUser`, `dbPassword`, `appMasterKey`, `initPassword`) are correct.

3. **Deploying the Chart:**
   ```bash
   az aks get-credentials --resource-group rg-secure-secret-sharer-mvp --name aks-securesharer-mvp --overwrite-existing
   helm upgrade <release-name> . --namespace <namespace> --install --create-namespace
   # Example:
   helm upgrade ss-mvp . --namespace default --install
   ```

## 4. Post-Deployment Verification

1. **Check Pod Statuses:**
   ```bash
   kubectl get pods --namespace default -w 
   ```
   Ensure frontend, backend, and database pods are `Running` and `READY 1/1`.

2. **Check Logs and Functionality:**
   * Review `kubectl describe pod <pod-name>` for events, especially for CSI volume mounts.
   * Check database pod logs for successful `init-db.sh` execution.
   * Check backend pod logs for successful DB connection and key initialization.

3. **Accessing via Ingress:**
   * Modify your local `hosts` file: `<App_Gateway_Public_IP> your.ingress.hostname` (e.g., `68.221.226.217 secretsharer.example.com`).
   * Navigate to `http://your.ingress.hostname` in your browser.
   * The frontend UI should load.

4. **Test Application:**
   * Submit a secret.
   * Verify the generated link (e.g., `http://your.ingress.hostname/api/reveal/...`).
   * Click the link to reveal; verify one-time access.
   * Test the "Copy Link" button.

## 5. Implementing CI/CD with Security Gates (Future Enhancement)

For future iterations, implement an automated CI/CD pipeline with integrated security scanning:

### Example GitHub Actions Workflow

```yaml
name: Build, Scan and Deploy

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build_and_scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Login to ACR
        uses: azure/docker-login@v1
        with:
          login-server: acrsecuresecsharer.azurecr.io
          username: ${{ secrets.ACR_USERNAME }}
          password: ${{ secrets.ACR_PASSWORD }}
      
      - name: Build frontend image
        run: |
          docker build -t acrsecuresecsharer.azurecr.io/secure-secret-sharer-frontend:${{ github.sha }} ./frontend
      
      - name: Build backend image
        run: |
          docker build -t acrsecuresecsharer.azurecr.io/secure-secret-sharer-backend:${{ github.sha }} ./backend
      
      - name: Install Trivy
        run: |
          curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
      
      - name: Scan frontend image
        run: |
          trivy image --exit-code 1 --severity HIGH,CRITICAL acrsecuresecsharer.azurecr.io/secure-secret-sharer-frontend:${{ github.sha }}
      
      - name: Scan backend image
        run: |
          trivy image --exit-code 1 --severity HIGH,CRITICAL acrsecuresecsharer.azurecr.io/secure-secret-sharer-backend:${{ github.sha }}
      
      - name: Push frontend image if scans pass
        run: |
          docker push acrsecuresecsharer.azurecr.io/secure-secret-sharer-frontend:${{ github.sha }}
      
      - name: Push backend image if scans pass
        run: |
          docker push acrsecuresecsharer.azurecr.io/secure-secret-sharer-backend:${{ github.sha }}
  
  deploy:
    needs: build_and_scan
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Set AKS context
        uses: azure/aks-set-context@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
          resource-group: rg-secure-secret-sharer-mvp
          cluster-name: aks-securesharer-mvp
      
      - name: Deploy to AKS
        run: |
          cd k8s/secret-sharer-app
          
          # Update values.yaml with new image tags
          sed -i "s/frontend.image.tag:.*/frontend.image.tag: \"${{ github.sha }}\"/g" values.yaml
          sed -i "s/backend.image.tag:.*/backend.image.tag: \"${{ github.sha }}\"/g" values.yaml
          
          # Install/upgrade Helm chart
          helm upgrade --install ss-mvp . --namespace default
```

## 6. Security Controls Details

### Network Policies

The Helm chart applies Kubernetes Network Policies that follow a zero-trust approach:

1. **Default Deny All Traffic:**
   This base policy denies all ingress and egress traffic in the namespace by default.

2. **Allow Backend to Database:**
   Specifically allows traffic from backend pods to database pods on port 5432.

3. **Allow Ingress to Frontend:**
   Allows traffic from the Ingress controller (AGIC) to frontend pods.

4. **Allow AGIC to Backend:**
   Allows traffic from the AGIC controller to backend pods for API requests.

### Key Vault Integration

The application uses Azure Key Vault Provider for Secrets Store CSI Driver to securely access secrets:

1. **SecretProviderClass Resources:**
   Define which Key Vault secrets to mount and how to expose them.

2. **Volume Mounts:**
   Mount the secrets as volumes in the appropriate pods.

3. **Environment Variables:**
   Reference mounted secrets as environment variables.

### RBAC (Role-Based Access Control)

Kubernetes RBAC is implemented to restrict pod permissions:

1. **Service Accounts:**
   Dedicated service accounts for each component.

2. **Roles and Role Bindings:**
   Least-privilege roles that grant only necessary permissions.

3. **Azure Role Assignments:**
   Azure RBAC roles assigned to Managed Identities for Key Vault access.

## 7. Further Security and Operational Considerations

### 1. Logging and Monitoring Strategy

* **Current State (MVP):** Basic console logging from the Python backend.
* **Future Considerations:** Structured logging, integration with Azure Monitor (Logs & Metrics), AKS diagnostic logs, SIEM integration (e.g., Microsoft Sentinel).

### 2. Input Validation

* **Current State (MVP):** Minimal.
* **Future Considerations (OWASP Awareness):** Robust server-side validation against common web vulnerabilities (XSS, SQLi, etc.), data type/length/format checks.

### 3. Rate Limiting

* **Current State (MVP):** None.
* **Future Considerations (Production):** Ingress-level (Application Gateway WAF) and potentially application-level rate limiting.

### 4. Basic Compliance Alignment (Conceptual)

* **Current State (MVP):** Foundational security controls.
* **Future Considerations:** Mapping to specific frameworks (GDPR, HIPAA, etc.), Azure Policy for Kubernetes.

### 5. Azure Security Recommendations Review

* **Current State (MVP):** Focused on secure deployment.
* **Future Considerations (Operational):** Regular review of Microsoft Defender for Cloud recommendations for AKS and related resources.

## 8. Future Enhancements

The following items are planned for future project iterations:

* Full CI/CD pipeline automation (e.g., GitHub Actions, Azure DevOps) including automated security scanning (Checkov, CodeQL, Trivy) and Helm tests.
* Infrastructure as Code (IaC) using Bicep or Terraform for provisioning all Azure resources.
* Advanced/Production-grade HTTPS for Ingress using cert-manager and Let's Encrypt.
* Detailed Threat Modeling (e.g., STRIDE).
* Implementation of comprehensive input validation.
* Implementation of rate limiting.
* Advanced Logging & Monitoring: Full structured logging to Azure Monitor, analysis of AKS Audit Logs, SIEM integration with Microsoft Sentinel, KQL queries.
* In-depth Cloud Security Posture Management (CSPM) work: Detailed remediation of Microsoft Defender for Cloud findings, Azure Policy for Kubernetes.
* CIS Benchmark analysis using tools like kube-bench.
* More comprehensive documentation, blog posts, and detailed compliance mapping.
