az stack group create \
  --name swa-platform-stack \
  --resource-group ss-d-swa-rg \
  --template-file main.bicep \
  --parameters main.dev.bicepparam \
  --action-on-unmanage deleteResources \
  --deny-settings-mode DenyWriteAndDelete \
  --deny-settings-apply-to-child-scopes \
  --deny-settings-excluded-actions \
    "Microsoft.App/containerApps/write, Microsoft.Authorization/roleAssignments/write"