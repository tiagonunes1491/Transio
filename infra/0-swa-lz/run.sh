az stack sub create \
  --name "lz-swa-stack" \
  --location spaincentral \
  --template-file main.bicep \
  --parameters main.dev.bicepparam \
  --deny-settings-mode DenyWriteAndDelete \
  --deny-settings-excluded-actions "Microsoft.App/containerApps/write, Microsoft.Authorization/roleAssignments/write"