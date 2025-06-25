az stack group create \
  --name shared-platform-stack \
  --resource-group ss-s-plat-rg \
  --template-file main.bicep \
  --parameters main.bicepparam \
  --action-on-unmanage deleteResources \
  --deny-settings-mode DenyWriteAndDelete \
  --deny-settings-apply-to-child-scopes \
  --deny-settings-excluded-actions \
      "Microsoft.ContainerRegistry/registries/PrivateEndpointConnectionsApproval/action, Microsoft.DocumentDB/databaseAccounts/PrivateEndpointConnectionsApproval/action"
