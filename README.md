Azure Infrastructure Setup (Manual - Azure Portal)
This section outlines the Azure resources that need to be manually provisioned for the "Secure Secret Sharer" MVP deployment.

1. Resource Group

All resources should be created within a single resource group for easier management.

Action: Create a new Resource Group.
Instructions (Azure Portal):
Navigate to "Resource groups" in the Azure Portal.
Click "+ Create".
Subscription: Select your Azure subscription.
Resource group name: e.g., rg-secure-secret-sharer-mvp
Region: Choose a suitable region (e.g., Spain Central, or your preferred region).
Click "Review + create", then "Create".
Note: All subsequent resources should be created in this resource group and region.
2. Azure Key Vault

This will store all application secrets.

Action: Create an Azure Key Vault instance.
Instructions (Azure Portal):
Navigate to "Key vaults".
Click "+ Create".
Basics Tab:
Resource group: Select the one created above (e.g., rg-secure-secret-sharer-mvp).
Key vault name: A globally unique name, e.g., kv-secure-secret-sharer (You've confirmed this name is available and in use).
Region: Same as your resource group.
Pricing tier: "Standard".
Recovery options: Ensure "Soft delete" is enabled (default) and enable "Purge protection".
Access configuration Tab:
Permission model: Select "Azure role-based access control".
Click "Review + create", then "Create".
Secrets to Create within this Key Vault:
After the Key Vault is created, navigate to it, go to "Secrets" under "Objects", and click "+ Generate/Import" for each of the following:
Name: postgres-password
Value: A strong, generated password for the PostgreSQL initial admin user.
Name: app-db-user
Value: The desired username string for your application's database user (e.g., secret_sharer_app_user).
Name: app-db-password
Value: A strong, generated password for the app-db-user.
Name: app-master-encryption-key
Value: A Fernet key (generate using python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())").
3. User Assigned Managed Identities (UAMIs)

Two separate identities are needed.

Action: Create two User Assigned Managed Identities.
Instructions (Azure Portal for each identity):
Navigate to "Managed Identities".
Click "+ Create".
Basics Tab:
Resource group: Select rg-secure-secret-sharer-mvp.
Region: Same as your resource group.
Name (Identity 1): id-secretsharer-backend
Name (Identity 2): id-secret-sharer-db-init
Click "Review + create", then "Create" for each.
Important: For each UAMI created, navigate to its "Overview" page and note down its "Client ID" and "Principal ID (Object ID)".
id-secretsharer-backend Client ID: fa376030-252d-443f-a32d-294e3cda90e1 (as you provided)
id-secret-sharer-db-init Client ID: ef9e4258-98dc-49a8-804b-dfe502309386 (as you provided)
4. Azure Key Vault Access Control (Assigning Permissions to UAMIs)

Grant the UAMIs permissions to read secrets from the Key Vault.

Action: Assign the "Key Vault Secrets User" role to both UAMIs on the kv-secure-secret-sharer Key Vault.
Instructions (Azure Portal):
Navigate to your Key Vault (kv-secure-secret-sharer).
Go to "Access control (IAM)" in the left menu.
Click "+ Add" -> "Add role assignment".
Role: Search for and select "Key Vault Secrets User". Click "Next".
Members:
Assign access to: "Managed identity".
Click "+ Select members".
Select id-secretsharer-backend. Click "Select".
Click "Next", then "Review + assign".
Repeat step 3-5 for the second UAMI:
Role: "Key Vault Secrets User".
Members: Select id-secret-sharer-db-init.
Click "Review + assign".
Verification: On the "Role assignments" tab of the Key Vault's IAM page, you should see both UAMIs listed with the "Key Vault Secrets User" role.
5. Azure Kubernetes Service (AKS) Cluster

Action: Create an AKS cluster with specific features enabled.
Instructions (Azure Portal):
Navigate to "Kubernetes services".
Click "+ Create" -> "Create a Kubernetes cluster".
Basics Tab:
Resource group: rg-secure-secret-sharer-mvp.
Kubernetes cluster name: aks-securesharer-mvp (as you created).
Region: spaincentral (as you created).
Kubernetes version: A recent stable version (e.g., 1.31.7 as you have).
API server availability (Pricing tier): "Standard".
Node pools Tab:
Configure at least one node pool (e.g., "agentpool" or "userpool"). For MVP, 1-2 nodes of a general-purpose size like Standard_DS2_v2 or Standard_B2ms is usually fine. You have Standard_D8ds_v5 which is more powerful, also fine.
Networking Tab:
Network configuration: Select "Azure CNI".
Network policy: Select "Azure".
Integrations Tab:
Scroll to "Secrets Store CSI Driver" and check "Enable Azure Key Vault Secrets Provider".
Advanced Tab (or relevant section for security/identity):
Ensure OIDC Issuer is Enabled.
Ensure Workload Identity is Enabled.
(These are often enabled by default when creating newer clusters or when enabling the Key Vault Secrets Provider add-on).
Review and create the cluster.
Important: After creation, navigate to the AKS cluster -> "Settings" -> "Properties" and note down the "OIDC issuer URL".
OIDC Issuer URL: https://spaincentral.oic.prod-aks.azure.com/6e05f665-11c4-4221-9eea-3065ede81619/9a581fdc-abe4-4935-8165-9d06b6320b8f/ (as per your provided cluster details).