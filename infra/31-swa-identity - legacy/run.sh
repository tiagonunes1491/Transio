az stack group create \
  --name swa-identity-stack \
  --resource-group ss-i-mgmt-rg \
  --template-file main.bicep \
  --parameters main.dev.bicepparam \
  --action-on-unmanage deleteResources \
  --deny-settings-mode DenyWriteAndDelete \
  --deny-settings-apply-to-child-scopes