


@description('Location for all resources deployed in the ARM template')
param location string = resourceGroup().location

@description('ExpressRoute peering location')
param erpeeringLocation string = 'Washington DC'

@description('Name of the ExpressRoute circuit')
param erCircuitName string = 'er-ckt01'

@description('Name of the ExpressRoute provider')
param serviceProviderName string = 'Equinix'

@allowed([
  'Premium'
  'Standard'
])
@description('Tier ExpressRoute circuit')
param erSKU_Tier string = 'Premium'

@allowed([
  'MeteredData'
  'UnlimitedData'
])
@description('Billing model ExpressRoute circuit')
param erSKU_Family string = 'MeteredData'

@allowed([
  50
  100
  200
  500
  1000
  2000
  5000
  10000
])
@description('Bandwidth ExpressRoute circuit')
param bandwidthInMbps int = 50

@description('autonomous system number used to create private peering between the customer edge router and MSEE routers')
param peerASN int = 65001

@description('point-to-point network prefix of primary link between the customer edge router and MSEE router')
param primaryPeerAddressPrefix string = '192.168.10.16/30'

@description('point-to-point network prefix of secondary link between the customer edge router and MSEE router')
param secondaryPeerAddressPrefix string = '192.168.10.20/30'

@description('VLAN Id used between the customer edge routers and MSEE routers. primary and secondary link have the same VLAN Id')
param vlanId int = 100

@description('name of the Virtual Network')
param vnetName string = 'vnet1'

@description('name of the subnet')
param subnet1Name string = 'subnet1'

@description('address space assigned to the Virtual Network')
param vnetAddressSpace string = '10.10.10.0/24'

@description('network prefix assigned to the subnet')
param subnet1Prefix string = '10.10.10.0/25'

@description('network prefixes assigned to the gateway subnet. It has to be a network prefix with mask /27 or larger')
param gatewaySubnetPrefix string = '10.10.10.224/27'

@description('name of the ExpressRoute Gateway')
param gatewayName string = 'er-gw'

@allowed([
  'Standard'
  'HighPerformance'
  'UltraPerformance'
  'ErGw1AZ'
  'ErGw2AZ'
  'ErGw3AZ'
])
@description('ExpressRoute Gateway SKU')
param gatewaySku string = 'HighPerformance'

var location_var = location
var erlocation = location
var erCircuitName_var = erCircuitName
var serviceProviderName_var = serviceProviderName
var erpeeringLocation_var = erpeeringLocation
var erSKU_Tier_var = erSKU_Tier
var erSKU_Family_var = erSKU_Family
var erSKU_Name = '${erSKU_Tier_var}_${erSKU_Family_var}'
var bandwidthInMbps_var = bandwidthInMbps
var peerASN_var = peerASN
var primaryPeerAddressPrefix_var = primaryPeerAddressPrefix
var secondaryPeerAddressPrefix_var = secondaryPeerAddressPrefix
var vlanId_var = vlanId
var vnetName_var = vnetName
var subnet1Name_var = subnet1Name
var vnetAddressSpace_var = vnetAddressSpace
var subnet1Prefix_var = subnet1Prefix
var gatewaySubnetPrefix_var = gatewaySubnetPrefix
var gatewayName_var = gatewayName
var gatewayPublicIPName_var = '${gatewayName_var}-pubIP'
var gatewaySku_var = gatewaySku
var nsg_var = 'nsg'

resource erCircuitName_resource 'Microsoft.Network/expressRouteCircuits@2020-06-01' = {
  name: erCircuitName_var
  location: erlocation
  sku: {
    name: erSKU_Name
    tier: erSKU_Tier_var
    family: erSKU_Family_var
  }
  properties: {
    serviceProviderProperties: {
      serviceProviderName: serviceProviderName_var
      peeringLocation: erpeeringLocation_var
      bandwidthInMbps: bandwidthInMbps_var
    }
    allowClassicOperations: false
  }
}

resource erCircuitName_AzurePrivatePeering 'Microsoft.Network/expressRouteCircuits/peerings@2020-06-01' = {
  name: '${erCircuitName_resource.name}/AzurePrivatePeering'
  location: erlocation
  properties: {
    peeringType: 'AzurePrivatePeering'
    peerASN: peerASN_var
    primaryPeerAddressPrefix: primaryPeerAddressPrefix_var
    secondaryPeerAddressPrefix: secondaryPeerAddressPrefix_var
    vlanId: vlanId_var
  }
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2020-06-01' = {
  name: nsg_var
  location: location_var
  properties: {
    securityRules: [
      {
        name: 'SSH-rule'
        properties: {
          description: 'allow SSH'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 500
          direction: 'Inbound'
        }
      }
      {
        name: 'RDP-rule'
        properties: {
          description: 'allow RDP'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 600
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource vnetName_resource 'Microsoft.Network/virtualNetworks@2020-06-01' = {
  name: vnetName_var
  location: location_var
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressSpace_var
      ]
    }
    subnets: [
      {
        name: subnet1Name_var
        properties: {
          addressPrefix: subnet1Prefix_var
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: gatewaySubnetPrefix_var
        }
      }
    ]
  }
}

resource gatewayPublicIPName 'Microsoft.Network/publicIPAddresses@2020-06-01' = {
  name: gatewayPublicIPName_var
  location: location_var
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

resource gatewayName_resource 'Microsoft.Network/virtualNetworkGateways@2020-06-01' = {
  name: gatewayName_var
  location: location_var
  properties: {
    ipConfigurations: [
      {
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName_var, 'GatewaySubnet')
          }
          publicIPAddress: {
            id: gatewayPublicIPName.id
          }
        }
        name: 'gwIPconf'
      }
    ]
    gatewayType: 'ExpressRoute'
    sku: {
      name: gatewaySku_var
      tier: gatewaySku_var
    }
    vpnType: 'RouteBased'
  }
  dependsOn: [
    vnetName_resource
  ]
}

output erCircuitName string = erCircuitName_var
output gatewayName string = gatewayName_var
output gatewaySku string = gatewaySku_var
