@description('Application name')
param appName string = 'secure-secret-sharer-aca-dev'

@description('Resource location')
param appLocation string

@description('Container image name (without registry)')
param containerImage string

@description('ACA Environment ID from the main deployment')
param environmentId string

@description('User Assigned Identity Id from the main deployment')
param userAssignedIdentityId string

@description('ACR Login Server from the main deployment')
param acrLoginServer string

@description('Key Vault URI from the main deployment')
param keyVaultUri string

@description('Key Vault secrets configuration')
@secure()
param keyVaultSecrets object

@description('Tags for the app')
param tags object

@description('SQL Server fully qualified domain name')
param postgresqlServerFqdn string 

@description('SQL Database name')
param databaseName string

@description('CPU limit for the ACA App')
param acaCpuLimit string

@description('Memory limit for the ACA App')
param acaMemoryLimit string

var acaEnvironmentVariables = [
  {
    name: 'DATABASE_HOST'
    value: postgresqlServerFqdn
  }
  {
    name: 'DATABASE_PORT'
    value: '5432'
  }
  {
    name: 'DATABASE_NAME'
    value: databaseName
  }
  {
    name: 'DATABASE_SSL_MODE'
    value: 'require'
  }
]

// Secret references - these will reference secrets stored in Key Vault
// Map Key Vault secret names to exact environment variable names expected by backend

//PR Change
var acaSecretReferences = [
  {
    name: 'DATABASE_USER'
    secretRef: keyVaultSecrets.databaseUser
  }
  {
    name: 'DATABASE_PASSWORD'
    secretRef: keyVaultSecrets.databasePassword
  }
  {
    name: 'MASTER_ENCRYPTION_KEY'
    secretRef: keyVaultSecrets.masterEncryptionKey
  }
]

module acaApp 'swa-aca-modules/aca-app.bicep' = {
  name: appName
  scope: resourceGroup()
  params: {
    appName: 'secure-secret-sharer-aca-dev'
    appLocation: appLocation
    environmentId: environmentId
    containerImage: '${acrLoginServer}/${containerImage}' 
    minReplicas: 0
    maxReplicas: 1
    targetPort: 5000
    externalIngress: true
    userAssignedIdentityId: userAssignedIdentityId
    secrets: [
      {
        name: keyVaultSecrets.databaseUser
        identity: userAssignedIdentityId
        keyVaultUri: '${keyVaultUri}secrets/${keyVaultSecrets.databaseUser}'
      }
      {
        name: keyVaultSecrets.databasePassword
        identity: userAssignedIdentityId
        keyVaultUri: '${keyVaultUri}secrets/${keyVaultSecrets.databasePassword}'
      }
      {
        name: keyVaultSecrets.masterEncryptionKey
        identity: userAssignedIdentityId
        keyVaultUri: '${keyVaultUri}secrets/${keyVaultSecrets.masterEncryptionKey}'
      }
    ]
    environmentVariables: acaEnvironmentVariables
    secretEnvironmentVariables: acaSecretReferences
    appTags: tags
    cpuLimit: acaCpuLimit
    memoryLimit: acaMemoryLimit
  }
}

// Output the ACA APP

output acaAppId string = acaApp.outputs.id
output AcaAppFqdn string = acaApp.outputs.fqdn
output acaAppName string = acaApp.outputs.name
