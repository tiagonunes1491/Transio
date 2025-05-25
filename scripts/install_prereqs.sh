#!/usr/bin/env bash
set -euo pipefail

# install_prereqs.sh - Install Azure CLI, Docker, kubectl, and Helm on Ubuntu (WSL)
# Run this inside the Ubuntu WSL distro

echo "[INFO] Updating package lists..."
sudo apt-get update

echo "[INFO] Installing prerequisites: ca-certificates, curl, gnupg, lsb-release..."
sudo apt-get install -y ca-certificates curl gnupg lsb-release

# Install Azure CLI
echo "[INFO] Installing Azure CLI..."
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Install Docker
echo "[INFO] Installing Docker..."
sudo apt-get install -y docker.io
sudo usermod -aG docker "$USER"

# Install kubectl
echo "[INFO] Installing kubectl..."
sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | \
  sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubectl

# Install Helm
echo "[INFO] Installing Helm..."
curl https://baltocdn.com/helm/signing.asc | sudo apt-key add -
echo "deb https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install -y helm

# Install Bicep
echo "[INFO] Installing Bicep CLI..."
az bicep install

# Setup WSL mounts for Windows hosts file
echo "[INFO] Verifying /mnt/c mount..."
if [ ! -d "/mnt/c" ]; then
  echo "[ERROR] /mnt/c not mounted. Ensure WSL is configured properly.";
  exit 1
fi

echo "[INFO] Prereqs installation complete. Close and re-open the Ubuntu shell to ensure Docker group membership is applied."
