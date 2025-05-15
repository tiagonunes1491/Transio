# Secure Secret Sharer: Cloud-Native Security Portfolio Project

## Executive Summary

A fully-secured, production-grade sensitive data sharing application deployed on Azure Kubernetes Service (AKS). This project demonstrates end-to-end implementation of cloud-native security controls including Workload Identity, Key Vault integration, container hardening, and network policy enforcement. Built using Python, PostgreSQL, Docker, and a comprehensive suite of Azure security services, this solution showcases modern security patterns for sensitive data handling in Kubernetes environments.

## Project Overview

The "Secure Secret Sharer" application allows a user to submit sensitive text (a "secret"). The Python backend encrypts this secret using a master encryption key (stored securely in Azure Key Vault) and generates a unique, one-time access link. When this link is visited, the secret is decrypted, displayed once to the user, and then permanently deleted from the system.

This project focuses on implementing a secure, multi-container version of this application on AKS, incorporating foundational cloud-native security best practices and defense-in-depth strategies.

## Architecture

[Architecture Diagram](docs/architecture-diagram.png)

The application consists of the following security-hardened tiers:

1. **Frontend**: Static web interface (HTML/JavaScript) served by an Nginx container with a non-root user
2. **Backend API**: Python (Flask/FastAPI) providing the core encryption/decryption logic
3. **Database**: Containerized PostgreSQL with strong authentication
4. **Secure Infrastructure**:
   - **Azure Kubernetes Service (AKS)**: Hosts all application containers with security controls
   - **Azure Key Vault (AKV)**: Securely stores all sensitive application data
   - **Azure Container Registry (ACR)**: Securely stores hardened container images
   - **Azure Application Gateway & AGIC**: Provides secure L7 load balancing and ingress

**Security-Focused Traffic Flow**:
* All external user traffic flows through the protected Application Gateway
* Backend accesses Key Vault securely via Azure Workload Identity (no credentials in code)
* Network policies enforce strict pod-to-pod communication rules
* All secrets are managed centrally in Azure Key Vault

## Key Security Highlights

- Defense-in-depth on AKS: Key Vault CSI, Workload Identity, AGIC, NetworkPolicies
- Hardened Docker images (multi-stage, non-root, Trivy-scanned)
- Least-privilege RBAC and UAMI design
- End-to-end encryption with centrally-managed master key
- Automated vulnerability management integrated into CI/CD

## Challenges and Solutions

1. **Challenge**: Securely providing application access to database credentials and encryption keys
   
   **Solution**: Implemented Azure Workload Identity with federated credentials and Key Vault CSI Driver, eliminating the need for static credentials in code or Kubernetes secrets. This approach leverages OIDC tokens for authentication, following the zero-trust principle.

2. **Challenge**: Ensuring secure network traffic flows within the AKS cluster
   
   **Solution**: Implemented default-deny Kubernetes Network Policies with specific allowances only for required communication paths. This creates a zero-trust networking model where only explicitly permitted traffic is allowed.
   
3. **Challenge**: Addressing container vulnerabilities found during security scanning
   
   **Solution**: Developed a systematic vulnerability management process including immediate remediation of critical findings, regular base image updates, and patch management. Implemented a comprehensive Trivy scanning workflow to detect vulnerabilities early.

4. **Challenge**: Securely exposing the application to the internet
   
   **Solution**: Configured Azure Application Gateway with the AGIC controller to act as a secure ingress point, enabling proper traffic routing while maintaining security controls.

## Container Vulnerability Management

Continuous Trivy scanning blocks HIGH/CRITICAL CVEs at build and deploy time. Detailed scan workflow, sample reports, and remediation steps are documented in [DEPLOYMENT.md](DEPLOYMENT.md#container-security-scanning-with-trivy).

## What I Learned

This project significantly deepened my expertise in:

- **Practical Cloud-Native Security**: Implementing real-world defense-in-depth strategies across containers, Kubernetes, and Azure services
- **Azure Identity Integration**: Configuring and troubleshooting Azure AD Workload Identity for Kubernetes workloads
- **Secure Infrastructure Design**: Balancing security controls with operational requirements
- **Kubernetes Security Patterns**: Applying zero-trust principles with Network Policies and RBAC
- **DevSecOps Integration**: Building security scanning into the deployment workflow
- **Vulnerability Management**: Creating practical remediation strategies for container security findings

## Roadmap

Planned enhancements: CI/CD automation, IaC (Bicep/Terraform), cert-manager, Sentinel, kube-bench, Azure Policy. Full list in [DEPLOYMENT.md](DEPLOYMENT.md#8-future-enhancements).

## Keywords

Azure, Kubernetes, AKS, Cloud Security, Container Security, DevSecOps, RBAC, Network Policies, Key Vault, 
Application Gateway, Workload Identity, CSI Driver, Helm, Docker, PostgreSQL, Python, Flask, Trivy, Zero Trust,
Defense-in-Depth, Encryption, Secrets Management, Infrastructure as Code, Vulnerability Management

## Technical Details

For detailed deployment instructions, please see [DEPLOYMENT.md](DEPLOYMENT.md).
