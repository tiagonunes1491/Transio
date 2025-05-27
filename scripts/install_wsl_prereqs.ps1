# install_wsl_prereqs.ps1 - Enable WSL and install Ubuntu distro
# Run in an elevated PowerShell console (as Administrator)

Write-Host "=== Installing WSL and Ubuntu Distro ===" -ForegroundColor Cyan

# 1) Enable the Windows Subsystem for Linux feature
Write-Host "Enabling WSL feature..." -ForegroundColor Cyan
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart | Out-Null
Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart | Out-Null

# 2) Install Ubuntu via WSL
Write-Host "Installing Ubuntu distro..." -ForegroundColor Cyan
wsl --install -d Ubuntu

# 3) Set default version to WSL 2
Write-Host "Setting WSL version to 2..." -ForegroundColor Cyan
wsl --set-default-version 2

Write-Host "WSL and Ubuntu installation completed." -ForegroundColor Green
Write-Host "Reboot Windows if prompted, then run 'install_prereqs.sh' inside Ubuntu (WSL) to install Azure CLI, Docker, kubectl, and Helm." -ForegroundColor Yellow
