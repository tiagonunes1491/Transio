# Secure Secret Sharer - Deployment Guide

This document provides detailed instructions for deploying the "Secure Secret Sharer" application to Azure Kubernetes Service (AKS) using the provided automation scripts and Bicep for infrastructure provisioning.

## 1. Prerequisites

Before you begin, ensure you have the following:

* **Azure Subscription**: An active Azure subscription where you have permissions to create and manage resources (Resource Groups, AKS, ACR, Key Vault, Application Gateway, Managed Identities, Role Assignments).
* **Azure CLI**: Installed and configured. Log in using `az login` and set your active subscription using `az account set --subscription "<Your-Subscription-ID>"`.
* **Docker**: Docker Desktop (Windows/Mac) or Docker Engine (Linux) installed and running for building container images.
* **kubectl**: Kubernetes command-line tool, installed.
* **Helm**: Helm v3+, the Kubernetes package manager, installed.
* **Bicep CLI**: Automatically installed by Azure CLI when a Bicep deployment is first triggered, or can be installed manually.
* **Git**: For cloning the project repository.
* **Project Repository**: Clone this project repository to your local machine.
    ```bash
    git clone <repository-url>
    cd secure-secret-sharer
    ```
* **(For Windows Users) WSL & Ubuntu**:
    * Ensure Windows Subsystem for Linux (WSL) is enabled and an Ubuntu distribution is installed. Run the `scripts/install_wsl_prereqs.ps1` script in an elevated PowerShell console.
    * Once WSL and Ubuntu are set up, open your Ubuntu terminal.
* **Development Tools in Ubuntu/WSL**:
    * Inside your Ubuntu (or other Linux/macOS) environment, run the `scripts/install_prereqs.sh` script to install Azure CLI (within WSL/Linux), Docker (within WSL/Linux, if not using Docker Desktop mapped to WSL2), kubectl, and Helm.
        ```bash
        cd scripts
        chmod +x install_prereqs.sh
        ./install_prereqs.sh
        cd ..
        ```
    * Ensure you close and reopen your Ubuntu shell after running `install_prereqs.sh` for Docker group membership changes to apply.

## 2. Automated Deployment with `build_dev.sh`

The `build_dev.sh` script, located in the root of the project, automates the majority of the deployment process.

### 2.1. Overview

The script performs the following actions:
1.  **(Optional) Full Rebuild**: If specified, tears down the existing Azure resource group and purges the Key Vault.
2.  **Azure Infrastructure Provisioning**: Deploys Azure resources (AKS, ACR, Key Vault, Application Gateway, Managed Identities, etc.) using Bicep templates located in the `infra/` directory (`main.bicep` and `main.dev.bicepparam`).
3.  **Retrieve Bicep Outputs**: Fetches necessary output values from the Bicep deployment (e.g., ACR login server, Key Vault name, UAMI client IDs).
4.  **(Optional) Build & Push Container Images**: Builds Docker images for the frontend and backend services and pushes them to the newly created Azure Container Registry (ACR).
5.  **Connect to AKS**: Configures `kubectl` to connect to the deployed AKS cluster.
6.  **Deploy Application**: Deploys the Secure Secret Sharer application to AKS using the Helm chart located in `k8s/secret-sharer-app/`. It dynamically sets values in the Helm chart based on the Bicep deployment outputs.

### 2.2. Configuration

* **Bicep Parameters**: Review and modify `infra/main.dev.bicepparam` if you need to change default resource names, locations (though the script uses a default location), or other infrastructure parameters *before* running the script.
* **Image Tags**: Default image tags for frontend and backend are defined at the top of `build_dev.sh`. You can modify these if needed.
    ```bash
    BACKEND_TAG="0.3.0"
    FRONTEND_TAG="0.3.0"
    ```
* **Key Vault Secrets**: The Bicep template provisions Azure Key Vault. However, the secrets themselves (`postgres-password`, `app-db-user`, `app-db-password`, `app-master-encryption-key`) **must be created manually in the Azure Key Vault** after the Key Vault is provisioned by the Bicep step in `build_dev.sh` but *before* the Helm deployment step is executed by the script.

    **Action Required: Create Secrets in Azure Key Vault**
    After the Bicep deployment part of `build_dev.sh` completes and your Key Vault (e.g., `kv-securesharer-dev` as per the Bicep variables, or the value outputted by the script) is created:
    1.  Navigate to your Key Vault in the Azure portal.
    2.  Go to **Secrets** and click **+ Generate/Import**.
    3.  Create the following secrets with appropriate values:
        * `postgres-password`: A strong password for the PostgreSQL initial admin user. (This name is referenced in `values.yaml` as `database.keyVault.secrets.initPassword`)
        * `app-db-user`: The username for the application's database user (e.g., `secret_sharer_app_user`). (This name is referenced in `values.yaml` as `backend.keyVault.secrets.dbUser`)
        * `app-db-password`: A strong password for the `app-db-user`. (This name is referenced in `values.yaml` as `backend.keyVault.secrets.dbPassword`)
        * `app-master-encryption-key`: A Fernet key. Generate one using:
            ```python
            python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
            ```
            (This name is referenced in `values.yaml` as `backend.keyVault.secrets.appMasterKey`)
    These secret names are referenced in the Helm chart's `values.yaml` and are used by the Secrets Store CSI Driver.

### 2.3. Running the Script

Navigate to the root of the project directory in your terminal (Ubuntu/WSL recommended).

Make the script executable:
```bash
chmod +x build_dev.sh
```

Run the script:
```bash
./build_dev.sh
```

**Script Options:**

* `--skip-infra`: Skips the Bicep infrastructure deployment. Useful if infrastructure is already deployed and you only want to update images/application.
* `--skip-containers`: Skips building and pushing container images. Useful if images are already in ACR.
* `--full-rebuild`: **Deletes the Azure resource group** (default: `rg-secure-secret-sharer-dev`) and purges the Key Vault before starting a new deployment. **Use with extreme caution.**
* `-h` or `--help`: Displays usage information.

Example: To run a full deployment including infrastructure and containers:
```bash
./build_dev.sh
```

Example: To redeploy the application assuming infrastructure and images are current:
```bash
./build_dev.sh --skip-infra --skip-containers
```

The script will output progress information. The Bicep deployment can take 10-20 minutes or more.

## 3. Post-Deployment Verification

After `build_dev.sh` completes:

1.  **Check Pod Statuses**:
    The script attempts to connect to AKS and get nodes. You can further check your application pods:
    ```bash
    kubectl get pods -n default -w
    ```
    Ensure `frontend`, `backend`, and `database` (e.g., `secret-sharer-db-0`) pods are in `Running` state and `READY` (e.g., `1/1`).

2.  **Inspect Logs**:
    * **Database Initialization**:
        ```bash
        kubectl logs <your-database-pod-name> -n default
        ```
        Look for messages from `init-db.sh` indicating successful user creation.
    * **Backend Application**:
        ```bash
        kubectl logs -l app.kubernetes.io/component=backend -n default --tail=100
        ```
        Check for successful connection to the database and initialization of the encryption suite.
    * **Secrets Store CSI Driver**: If pods are having trouble mounting secrets:
        ```bash
        kubectl describe pod <pod-name-with-csi-volume> -n default
        kubectl logs -n kube-system -l app=secrets-store-provider-azure
        kubectl logs -n kube-system -l app=secrets-store-csi-driver
        ```

3.  **Verify Ingress and Application Gateway**:
    * Check the status of the Ingress resource:
        ```bash
        kubectl get ingress -n default
        ```
    * In the Azure portal, navigate to your Application Gateway (e.g., `appgw-secretsharer`) and check its "Backend health" to ensure it can reach the backend services in AKS.

## 4. Accessing the Application

The `build_dev.sh` script will output instructions for updating your local `hosts` file. This is necessary to resolve the custom hostname (e.g., `secretsharer.local`) to the Public IP address of the Azure Application Gateway.

1.  **Update Hosts File**:
    * The script provides PowerShell commands for Windows. For Linux/macOS, edit `/etc/hosts` manually.
    * Example line to add (replace `<APP_GW_IP>` and `secretsharer.local` if different, based on script output):
        ```
        <APP_GW_IP> secretsharer.local
        ```
        You can get the `<APP_GW_IP>` from the script's output (`APP_GW_IP` variable).

2.  **Access in Browser**:
    Open your web browser and navigate to `http://secretsharer.local` (or your configured hostname as per the `HOSTNAME` variable in `build_dev.sh`).

## 5. Understanding the Deployed Infrastructure

The `infra/main.bicep` file defines all Azure resources. Key components include:

* **Azure Resource Group**: A container for all resources (e.g., `rg-secure-secret-sharer-dev`).
* **Azure Container Registry (ACR)**.
* **Azure Key Vault (KV)**.
* **User Assigned Managed Identities (UAMIs)**:
    * One for the backend application to access Key Vault.
    * One for the database init container to access Key Vault.
* **Azure Kubernetes Service (AKS)**: Managed Kubernetes cluster.
    * Configured with OIDC Issuer and Workload Identity enabled.
    * Secrets Store CSI Driver add-on enabled.
* **Azure Application Gateway**: L7 Load Balancer and Ingress controller.
* **Associated Networking**: Virtual Network, Subnets, Public IP Addresses.
* **Role Assignments**: For UAMIs to access Key Vault.

Refer to `infra/main.bicep` and `infra/main.dev.bicepparam` for detailed definitions.

## 6. Cleanup / Teardown

To remove all deployed Azure resources:

**Manual Deletion**:
 If you prefer to delete manually or if the script encounters issues:
 * **Delete Resource Group**:
     ```bash
     # Identify your resource group name (e.g., rg-secure-secret-sharer-dev from build_dev.sh output)
     az group delete --name <your-resource-group-name> --yes --no-wait
     ```
 * **Purge Key Vault**: If purge protection was enabled and the Key Vault is soft-deleted, you might need to purge it manually from the Azure Portal or via CLI:
     ```bash
     # List soft-deleted vaults
     az keyvault list-deleted
     # Purge a specific vault (name and location from build_dev.sh output or your bicepparam file)
     az keyvault purge --name <keyvault-name> --location <keyvault-location>
     ```

Remember to remove the entry from your local `hosts` file after cleanup.
