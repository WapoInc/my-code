
@description('Route based or policy based')
@allowed([
  'RouteBased'
  'PolicyBased'
])
param vpnType string = 'RouteBased'

@description('Arbitrary name for gateway resource representing')
param localGatewayName string = 'localGateway'

@description('Public IP of your StrongSwan Instance')
param localGatewayIpAddress string = '1.1.1.1'

@description('CIDR block representing the address space of the OnPremise VPN network\'s Subnet')
param localAddressPrefix array = [
  '192.168.2.0/24'
  '172.16.22.0/24'
]

@description('Arbitrary name for the Azure Virtual Network')
param virtualNetworkName string = 'azureVnet'

@description('CIDR block representing the address space of the Azure VNet')
param azureVNetAddressPrefix string = '10.101.0.0/16'

@description('Arbitrary name for the Azure Subnet')
param subnetName string = 'Subnet1'

@description('CIDR block for VM subnet, subset of azureVNetAddressPrefix address space')
param subnetPrefix string = '10.101.1.0/24'

@description('CIDR block for gateway subnet, subset of azureVNetAddressPrefix address space')
param gatewaySubnetPrefix string = '10.101.0.0/27'

@description('Arbitrary name for public IP resource used for the new azure gateway')
param gatewayPublicIPName string = 'azureGatewayIP'

@description('Arbitrary name for the new gateway')
param gatewayName string = 'azureGateway'

@description('The Sku of the Gateway. This must be one of Basic, Standard or HighPerformance.')
@allowed([
  'VpnGw1'
  'VpnGw2'
  'VpnGw3'
  'VpnGw4'
  'VpnGw5'
  'Standard'
  'HighPerformance'
  'UltraPerformance'
])
param gatewaySku string = 'VpnGw1'

@description('Arbitrary name for the new connection between Azure VNet and other network')
param connectionName string = 'S2S-OnPrem-to-Azure'

@description('Shared key (PSK) for IPSec tunnel')
@secure()
param sharedKey string
param location string = resourceGroup().location

var gatewaySubnetRef = resourceId('Microsoft.Network/virtualNetworks/subnets/', virtualNetworkName, 'GatewaySubnet')

resource localGateway 'Microsoft.Network/localNetworkGateways@2020-08-01' = {
  name: localGatewayName
  location: location
  properties: {
    localNetworkAddressSpace: {
      addressPrefixes: localAddressPrefix
    }
    gatewayIpAddress: localGatewayIpAddress
  }
}

resource connection 'Microsoft.Network/connections@2020-07-01' = {
  name: connectionName
  location: location
  properties: {
    virtualNetworkGateway1: {
      id: gateway.id
    }
    localNetworkGateway2: {
      id: localGateway.id
    }
    connectionType: 'IPsec'
    routingWeight: 10
    sharedKey: sharedKey
  }
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2015-06-15' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        azureVNetAddressPrefix
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetPrefix
        }
      }
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: gatewaySubnetPrefix
        }
      }
    ]
  }
}

resource gatewayPublicIP 'Microsoft.Network/publicIPAddresses@2015-06-15' = {
  name: gatewayPublicIPName
  location: location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

resource gateway 'Microsoft.Network/virtualNetworkGateways@2015-06-15' = {
  name: gatewayName
  location: location
  properties: {
    ipConfigurations: [
      {
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: gatewaySubnetRef
          }
          publicIPAddress: {
            id: gatewayPublicIP.id
          }
        }
        name: 'vnetGatewayConfig'
      }
    ]
    sku: {
      name: gatewaySku
      tier: gatewaySku
    }
    gatewayType: 'Vpn'
    vpnType: vpnType
    enableBgp: false
  }
  dependsOn: [

    virtualNetwork
  ]
}
