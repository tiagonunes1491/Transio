@description('Name of the resource group.')
param rgName string

@description('Location for the resource group.')
param location string

@description('Tags to apply to the resource group.')
param tags object = {}

targetScope = 'subscription' 

resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: rgName
  location: location
  tags: tags
}

@description('The name of the created resource group.')
output name string = rg.name

@description('The resource ID of the created resource group.')
output id string = rg.id
