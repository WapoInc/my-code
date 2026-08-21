// Hub network stack in the hub subscription: subnet layout, public IP, and ExpressRoute gateway.
// Subnets are declared as child resources of the existing hub VNet, so other subnets are preserved.
targetScope = 'resourceGroup'

param location string
param hubVnetName string
param defaultSubnetName string = 'default'
param defaultSubnetPrefix string = '10.100.1.0/25'
param gatewaySubnetPrefix string = '10.100.1.128/27'
param ergwName string = 'hub-tnet-ergw'
param ergwPublicIpName string = 'hub-tnet-ergw-pip'
param ergwSku string = 'ErGw1AZ'

resource hubVnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: hubVnetName
}

resource defaultSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: hubVnet
  name: defaultSubnetName
  properties: {
    addressPrefix: defaultSubnetPrefix
  }
}

// Subnets on one VNet cannot be written in parallel; serialize after the default subnet.
resource gatewaySubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: hubVnet
  name: 'GatewaySubnet'
  properties: {
    addressPrefix: gatewaySubnetPrefix
  }
  dependsOn: [
    defaultSubnet
  ]
}

resource ergwPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: ergwPublicIpName
  location: location
  sku: {
    name: 'Standard'
  }
  zones: [
    '1'
    '2'
    '3'
  ]
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

resource ergw 'Microsoft.Network/virtualNetworkGateways@2024-05-01' = {
  name: ergwName
  location: location
  properties: {
    gatewayType: 'ExpressRoute'
    sku: {
      name: ergwSku
      tier: ergwSku
    }
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: gatewaySubnet.id
          }
          publicIPAddress: {
            id: ergwPublicIp.id
          }
        }
      }
    ]
  }
}

output ergwId string = ergw.id
