az stack sub create \
  --name "lz-swa-stack" \
  --location spaincentral \
  --template-file main.bicep \
  --parameters main.dev.bicepparam \
  --action-on-unmanage deleteAll \
  --deny-settings-mode DenyWriteAndDelete \
  --deny-settings-apply-to-child-scopes \
  --deny-settings-excluded-actions \
    "Microsoft.Resources/deployments/write Microsoft.App/containerApps/write Microsoft.Web/staticSites/publish/action"

