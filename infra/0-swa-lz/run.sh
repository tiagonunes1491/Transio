az stack sub create \
  --name "lz-swa-stack" \
  --location spaincentral \
  --template-file main.bicep \
  --parameters main.dev.bicepparam \
  --action-on-unmanage deleteAll \
  --deny-settings-mode DenyWriteAndDelete \
  --deny-settings-excluded-actions \
    "Microsoft.Resources/deployments/write"

  az deployment sub create \
  --name "lz-swa-deployment" \
  --location spaincentral \
  --template-file main.bicep \
  --parameters main.dev.bicepparam