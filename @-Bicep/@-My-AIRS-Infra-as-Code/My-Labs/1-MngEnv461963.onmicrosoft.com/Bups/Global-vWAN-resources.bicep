targetScope = 'resourceGroup'

@description('Azure region for the Virtual WAN and Virtual Hub.')
param location string = 'southafricanorth'

@description('Name of the Azure Virtual WAN.')
param virtualWanName string = 'Global-vWAN'

@description('Name of the Azure Virtual Hub.')
param virtualHubName string = 'ZAN-Hub-1'

@description('Address prefix assigned to the Azure Virtual Hub.')
param virtualHubAddressPrefix string = '10.200.1.0/24'

@description('Resource tags applied to the Virtual WAN and Virtual Hub.')
param tags object = {}

resource virtualWan 'Microsoft.Network/virtualWans@2024-05-01' = {
  name: virtualWanName
  location: location
  tags: tags
  properties: {
    allowBranchToBranchTraffic: true
    type: 'Standard'
  }
}

resource virtualHub 'Microsoft.Network/virtualHubs@2024-05-01' = {
  name: virtualHubName
  location: location
  tags: tags
  properties: {
    addressPrefix: virtualHubAddressPrefix
    sku: 'Standard'
    virtualWan: {
      id: virtualWan.id
    }
  }
}

output virtualWanId string = virtualWan.id
output virtualHubId string = virtualHub.id
