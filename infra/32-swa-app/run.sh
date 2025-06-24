az deployment group create --name "swa-application-$(date +%Y%m%d%H%M%S)" --resource-group "ss-d-swa-rg" --template-file "main.bicep" --parameters "main.dev.bicepparam"
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