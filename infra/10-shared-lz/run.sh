az stack sub create \
  --name lz-shared-stack \
  --location spaincentral \
  --template-file main.bicep \
  --parameters main.bicepparam \
  --action-on-unmanage deleteAll \
  --deny-settings-mode DenyWriteAndDelete \
  --deny-settings-apply-to-child-scopes \
  --deny-settings-excluded-actions "Microsoft.Resources/deployments/write,Microsoft.ContainerRegistry/registries/PrivateEndpointConnectionsApproval/action, Microsoft.DocumentDB/databaseAccounts/PrivateEndpointConnectionsApproval/action"