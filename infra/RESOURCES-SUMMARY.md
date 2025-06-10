# Landing Zone Resources Summary

## Resource Groups Created

Your `landing-zone.bicep` creates **4 Resource Groups**:

1. **Management RG**: `rg-ssharer-mgmt-{environmentName}`
   - Contains all User Assigned Managed Identities (UAMIs)
   - Central management location for identities

2. **Hub RG**: `rg-ssharer-artifacts-hub`
   - Shared artifacts like Azure Container Registry
   - Environment-agnostic shared resources

3. **K8s Spoke RG**: `rg-ssharer-k8s-spoke-{environmentName}`
   - Kubernetes cluster and related resources
   - Environment-specific K8s workloads

4. **PaaS Spoke RG**: `rg-ssharer-paas-spoke-{environmentName}`
   - Platform-as-a-Service resources (Container Apps, etc.)
   - Environment-specific PaaS workloads

## User Assigned Managed Identities (UAMIs) Created

Your `landing-zone.bicep` creates **4 UAMIs**:

1. **ACR UAMI**: `uami-ssharer-acr-{environmentName}`
   - **Purpose**: Container registry operations
   - **Permissions**: AcrPush role on Hub RG
   - **GitHub Federation**: ✅ Enabled

2. **K8s UAMI**: `uami-ssharer-k8s-{environmentName}`
   - **Purpose**: Kubernetes cluster management
   - **Permissions**: 
     - Contributor role on K8s Spoke RG
     - AcrPull role on Hub RG
   - **GitHub Federation**: ✅ Enabled

3. **K8s Deploy UAMI**: `uami-ssharer-k8s-deploy-{environmentName}`
   - **Purpose**: Kubernetes application deployments
   - **Permissions**: AcrPull role on Hub RG
   - **GitHub Federation**: ✅ Enabled

4. **PaaS UAMI**: `uami-ssharer-paas-{environmentName}`
   - **Purpose**: PaaS workload management
   - **Permissions**: 
     - Contributor role on PaaS Spoke RG
     - AcrPull role on Hub RG
   - **GitHub Federation**: ✅ Enabled

## Outputs Available

The template outputs all resource group names and UAMI details including:
- Resource Group names
- UAMI names, principal IDs, and client IDs
- Environment information
- Tenant and subscription IDs

## GitHub Actions Integration

All UAMIs are federated with GitHub Actions using OpenID Connect (OIDC) for secure, passwordless authentication. Use the client IDs in your GitHub Actions workflows.
