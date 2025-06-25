az stack group create --name swa-deployment-stack --resource-group ss-d-swa-rg  --template-file main.bicep --parameters main.dev.bicepparam  --deny-settings-mode None --action-on-unmanage detachAll
read -rsn1 -p "Press any key to continue..."

# Change to the project root directory for proper path resolution
cd ../..

# Deploy to the default environment (which has the backend linked)
swa deploy \
  --app-name ss-d-swa-swa \
  --app-location frontend/static \
  --output-location . \
  --env default \
  --verbose

  az stack group create --name swa-platform-stack --resource-group ss-d-swa-rg  --template-file main.bicep --parameters main.dev.bicepparam  --deny-settings-mode None --action-on-unmanage detachAll