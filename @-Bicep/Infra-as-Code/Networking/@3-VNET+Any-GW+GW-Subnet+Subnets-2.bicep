// Create a VNET VPN GW and Subnets using tips from Bicep for real YouTube @ https://youtu.be/bRxtHMoezGI?list=PLeh9xH-kbPPY-6hUKuLKhFu_w2tKFVpl3
param location string = resourceGroup().location

@description('Select a project prefix')
param prefix string 

@description('Select the Gateway Type')
@allowed([
  'Vpn'
  'ExpressRoute'
])
param gatewayType string

@description('The SKU for the VPN Gateway')
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
param gatewaySku string

@description('Choos the GW Generation')
@allowed([
  'Generation1'
  'Generation2'
])
param vpnGatewayGeneration string

@description('Enter all the VNET and Subnet settings')
var vnet1cfg = {
  name: '${prefix}-vNet1-${location}'
  addressSpacePrefix: '172.16.0.0/12'
  subnetName: 'subnet1'
  subnetPrefix: '172.16.1.0/24'
  gatewayName: '${gatewayType}-Gateway'
  gatewaySubnetPrefix: '172.16.0.0/27'
  gatewayPublicIPName: '${gatewayType}-${gatewaySku}-Pub-IP'
  connectionName: 'vNet1-to-vNet2'
  asn: 65010
}

resource gw1pip 'Microsoft.Network/publicIPAddresses@2020-06-01' = {
  name: vnet1cfg.gatewayPublicIPName
  location: location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

resource vnet1 'Microsoft.Network/virtualNetworks@2020-06-01' = {
  name: vnet1cfg.name
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnet1cfg.addressSpacePrefix
      ]
    }
    subnets: [
      {
        name: vnet1cfg.subnetName
        properties: {
          addressPrefix: vnet1cfg.subnetPrefix
        }
      }
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: vnet1cfg.gatewaySubnetPrefix
        }
      }
    ]
  }
}

resource vnet1Gateway 'Microsoft.Network/virtualNetworkGateways@2020-06-01' = {
  name: vnet1cfg.gatewayName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'vnet1GatewayConfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets',vnet1.name,'GatewaySubnet')
          }
          publicIPAddress: {
            id: gw1pip.id
          }
        }
      }
    ]
    vpnGatewayGeneration: vpnGatewayGeneration
    gatewayType: gatewayType
    sku: {
      name: gatewaySku
      tier: gatewaySku
    }
    vpnType: 'RouteBased'
    }
}



