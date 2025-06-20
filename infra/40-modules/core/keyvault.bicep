// Azure Key Vault configuration
// Creates and configures Key Vault with RBAC for secure secret management
@minLength(3)
@maxLength(24)
@description('Name of the keyvault')
param keyvaultName string = 'keyvault'

@description('Location for the keyvault')
param location string = 'spaincentral'

@description('Tags for the keyvault')
param tags object = {}

@description('SKU for the keyvault')
@allowed([
  'standard'
  'premium'
])
param sku string = 'standard'

@description('Tenant ID for the keyvault')
param tenantId string = subscription().tenantId

@description('Enable rbac for the keyvault')
param enableRbac bool = true


@description('Enable purge protection for the keyvault')
param enablePurgeProtection bool = true

@description('Secure object for secrets')
@secure()
param secretsToSet object = {}

resource akv 'Microsoft.KeyVault/vaults@2024-11-01' = {
  name: keyvaultName
  location: location
  tags: tags
  properties: {
    tenantId: tenantId
    enableRbacAuthorization: enableRbac
    ...enablePurgeProtection ? { enablePurgeProtection: true } : {}
    sku: {
      family: 'A'
      name: sku
    }
  }
}

resource kvSecrets 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = [
  for secret in items(secretsToSet): {
  parent: akv
  name: secret.key
  properties: {
    value: string(secret.value)
  }
}]

output keyvaultId string = akv.id
output keyvaultName string = akv.name
output keyvaultUri string = akv.properties.vaultUri
