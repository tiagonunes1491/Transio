az stack group create \
  --name swa-platform-stack \
  --resource-group ss-d-swa-rg \
  --template-file main.bicep \
  --parameters main.dev.bicepparam \
