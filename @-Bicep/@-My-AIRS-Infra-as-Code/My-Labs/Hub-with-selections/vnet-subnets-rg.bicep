targetScope = 'subscription'

@description('Name of the resource group to create for the virtual network.')
param resourceGroupName string

@description('Azure region for the resource group and virtual network.')
param location string

@description('Name of the virtual network.')
param vnetName string

@description('IPv4 address space for the virtual network.')
param vnetCidr string

resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
  tags: {
    purpose: 'networking-lab'
  }
}

module vnet 'vnet-subnets-resources.bicep' = {
  scope: resourceGroup
  params: {
    location: location
    vnetName: vnetName
    vnetCidr: vnetCidr
  }
}

output resourceGroupName string = resourceGroup.name
output vnetName string = vnet.outputs.name
output vnetId string = vnet.outputs.id
