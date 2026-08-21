targetScope = 'resourceGroup'

@description('Azure region for the virtual network.')
param location string = resourceGroup().location

@description('Name of the virtual network.')
param vnetName string

@description('IPv4 address space for the virtual network.')
param vnetCidr string

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetCidr
      ]
    }
  }
}

output name string = vnet.name
output id string = vnet.id
