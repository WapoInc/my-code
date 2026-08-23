targetScope = 'resourceGroup'

param location string
param hubVnetName string
param hubWorkloadNsgName string
param vpnGatewayName string
param vpnGatewayPublicIpName string

param createHubVnet bool
param createHubWorkloadNsg bool
param createGatewaySubnet bool
param createVpnGatewayPublicIp bool
param createVpnGateway bool
param createFirewallSubnet bool
param createFirewallManagementSubnet bool
param createHubWorkloadSubnet bool
param createPingTestSubnet bool
param createSpokeVnets array
param createSpokeSubnets array
param createHubToSpokePeerings array
param createSpokeToHubPeerings array

var spokeConfigs = [
  {
    name: 'za-east-spoke-1'
    vnetName: 'za-east-spoke-1-vnet'
    vnetPrefix: '10.21.0.0/24'
    subnetPrefix: '10.21.0.0/25'
  }
  {
    name: 'za-east-spoke-2'
    vnetName: 'za-east-spoke-2-vnet'
    vnetPrefix: '10.22.0.0/24'
    subnetPrefix: '10.22.0.0/25'
  }
  {
    name: 'za-east-spoke-3'
    vnetName: 'za-east-spoke-3-vnet'
    vnetPrefix: '10.23.0.0/24'
    subnetPrefix: '10.23.0.0/25'
  }
]

resource hubWorkloadNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = if (createHubWorkloadNsg) {
  name: hubWorkloadNsgName
  location: location
  properties: {
    securityRules: []
  }
}

resource hubVnet 'Microsoft.Network/virtualNetworks@2024-05-01' = if (createHubVnet) {
  name: hubVnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.20.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: '10.20.0.0/24'
        }
      }
      {
        name: 'ZA-East-Hub'
        properties: {
          addressPrefix: '10.20.1.0/24'
          networkSecurityGroup: {
            id: resourceId('Microsoft.Network/networkSecurityGroups', hubWorkloadNsgName)
          }
        }
      }
      {
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: '10.20.6.64/26'
        }
      }
      {
        name: 'AzureFirewallManagementSubnet'
        properties: {
          addressPrefix: '10.20.7.0/24'
        }
      }
      {
        name: 'Ping-test'
        properties: {
          addressPrefix: '10.20.8.0/24'
        }
      }
    ]
  }
  dependsOn: [
    hubWorkloadNsg
  ]
}

resource existingHubVnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: hubVnetName
}

resource gatewaySubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = if (!createHubVnet && createGatewaySubnet) {
  parent: existingHubVnet
  name: 'GatewaySubnet'
  properties: {
    addressPrefix: '10.20.0.0/24'
  }
}

resource existingGatewaySubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = {
  parent: existingHubVnet
  name: 'GatewaySubnet'
}

resource vpnGatewayPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = if (createVpnGatewayPublicIp) {
  name: vpnGatewayPublicIpName
  location: location
  zones: [
    '1'
    '2'
    '3'
  ]
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource existingVpnGatewayPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' existing = {
  name: vpnGatewayPublicIpName
}

resource vpnGateway 'Microsoft.Network/virtualNetworkGateways@2024-05-01' = if (createVpnGateway) {
  name: vpnGatewayName
  location: location
  properties: {
    activeActive: false
    enableBgp: false
    gatewayType: 'Vpn'
    ipConfigurations: [
      {
        name: 'default'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: existingVpnGatewayPublicIp.id
          }
          subnet: {
            id: existingGatewaySubnet.id
          }
        }
      }
    ]
    sku: {
      name: 'Basic'
      tier: 'Basic'
    }
    vpnGatewayGeneration: 'Generation1'
    vpnType: 'RouteBased'
  }
  dependsOn: [
    gatewaySubnet
    hubVnet
    vpnGatewayPublicIp
  ]
}

resource hubWorkloadSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = if (!createHubVnet && createHubWorkloadSubnet) {
  parent: existingHubVnet
  name: 'ZA-East-Hub'
  properties: {
    addressPrefix: '10.20.1.0/24'
    networkSecurityGroup: {
      id: resourceId('Microsoft.Network/networkSecurityGroups', hubWorkloadNsgName)
    }
  }
  dependsOn: [
    hubWorkloadNsg
  ]
}

resource firewallSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = if (!createHubVnet && createFirewallSubnet) {
  parent: existingHubVnet
  name: 'AzureFirewallSubnet'
  properties: {
    addressPrefix: '10.20.6.64/26'
  }
}

resource firewallManagementSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = if (!createHubVnet && createFirewallManagementSubnet) {
  parent: existingHubVnet
  name: 'AzureFirewallManagementSubnet'
  properties: {
    addressPrefix: '10.20.7.0/24'
  }
}

resource pingTestSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = if (!createHubVnet && createPingTestSubnet) {
  parent: existingHubVnet
  name: 'Ping-test'
  properties: {
    addressPrefix: '10.20.8.0/24'
  }
}

resource spokeVnets 'Microsoft.Network/virtualNetworks@2024-05-01' = [
  for (spoke, index) in spokeConfigs: if (createSpokeVnets[index]) {
    name: spoke.vnetName
    location: location
    properties: {
      addressSpace: {
        addressPrefixes: [
          spoke.vnetPrefix
        ]
      }
      subnets: [
        {
          name: 'Subnet-1'
          properties: {
            addressPrefix: spoke.subnetPrefix
          }
        }
      ]
    }
  }
]

resource existingSpokeVnets 'Microsoft.Network/virtualNetworks@2024-05-01' existing = [
  for spoke in spokeConfigs: {
    name: spoke.vnetName
  }
]

resource spokeSubnets 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = [
  for (spoke, index) in spokeConfigs: if (!createSpokeVnets[index] && createSpokeSubnets[index]) {
    parent: existingSpokeVnets[index]
    name: 'Subnet-1'
    properties: {
      addressPrefix: spoke.subnetPrefix
    }
  }
]

resource hubToSpokePeerings 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = [
  for (spoke, index) in spokeConfigs: if (createHubToSpokePeerings[index]) {
    name: 'hub-to-${spoke.name}'
    parent: existingHubVnet
    properties: {
      remoteVirtualNetwork: {
        id: resourceId('Microsoft.Network/virtualNetworks', spoke.vnetName)
      }
      allowVirtualNetworkAccess: true
      allowForwardedTraffic: true
      allowGatewayTransit: false
      useRemoteGateways: false
    }
    dependsOn: [
      hubVnet
      spokeVnets
    ]
  }
]

resource spokeToHubPeerings 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = [
  for (spoke, index) in spokeConfigs: if (createSpokeToHubPeerings[index]) {
    name: '${spoke.name}-to-hub'
    parent: existingSpokeVnets[index]
    properties: {
      remoteVirtualNetwork: {
        id: resourceId('Microsoft.Network/virtualNetworks', hubVnetName)
      }
      allowVirtualNetworkAccess: true
      allowForwardedTraffic: true
      allowGatewayTransit: false
      useRemoteGateways: false
    }
    dependsOn: [
      hubVnet
      spokeVnets
      hubToSpokePeerings
    ]
  }
]

output hubVnetId string = resourceId('Microsoft.Network/virtualNetworks', hubVnetName)
output spokeVnetIds array = [for spoke in spokeConfigs: resourceId('Microsoft.Network/virtualNetworks', spoke.vnetName)]
output vpnGatewayId string = resourceId('Microsoft.Network/virtualNetworkGateways', vpnGatewayName)
output vpnGatewayPublicIpId string = existingVpnGatewayPublicIp.id
