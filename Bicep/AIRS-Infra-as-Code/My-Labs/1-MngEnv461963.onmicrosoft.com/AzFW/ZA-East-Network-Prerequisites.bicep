targetScope = 'resourceGroup'

param location string
param hubVnetName string
param hubWorkloadNsgName string
param vpnGatewayName string
param vpnGatewayPublicIpName string
param vpnGatewaySku string

param vmAdminUsername string = 'rootadmin'

@secure()
param vmAdminPassword string

param vmSize string = 'Standard_B1ls'

param createHubVnet bool
param createHubWorkloadNsg bool
param createGatewaySubnet bool
param createVpnGatewayPublicIp bool
param createVpnGateway bool
param createFirewallSubnet bool
param createFirewallManagementSubnet bool
param createPingTestSubnet bool
param createHubVmSubnet bool
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
    vmPrivateIp: '10.21.0.5'
  }
  {
    name: 'za-east-spoke-2'
    vnetName: 'za-east-spoke-2-vnet'
    vnetPrefix: '10.22.0.0/24'
    subnetPrefix: '10.22.0.0/25'
    vmPrivateIp: '10.22.0.5'
  }
  {
    name: 'za-east-spoke-3'
    vnetName: 'za-east-spoke-3-vnet'
    vnetPrefix: '10.23.0.0/24'
    subnetPrefix: '10.23.0.0/25'
    vmPrivateIp: '10.23.0.5'
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
      {
        name: 'Subnet-1'
        properties: {
          addressPrefix: '10.20.1.0/25'
          networkSecurityGroup: {
            id: resourceId('Microsoft.Network/networkSecurityGroups', hubWorkloadNsgName)
          }
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

// Gen1 covers Basic and the first-generation VpnGw SKUs; everything else is Gen2.
var vpnGatewayGeneration = contains(['Basic', 'VpnGw1', 'VpnGw1AZ'], vpnGatewaySku) ? 'Generation1' : 'Generation2'

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
      name: vpnGatewaySku
      tier: vpnGatewaySku
    }
    vpnGatewayGeneration: vpnGatewayGeneration
    vpnType: 'RouteBased'
  }
  dependsOn: [
    gatewaySubnet
    hubVnet
    vpnGatewayPublicIp
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

resource hubVmSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = if (!createHubVnet && createHubVmSubnet) {
  parent: existingHubVnet
  name: 'Subnet-1'
  properties: {
    addressPrefix: '10.20.1.0/25'
    networkSecurityGroup: {
      id: resourceId('Microsoft.Network/networkSecurityGroups', hubWorkloadNsgName)
    }
  }
  dependsOn: [
    hubWorkloadNsg
  ]
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

resource hubVmNic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: 'za-east-${location}-vm-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', hubVnetName, 'Subnet-1')
          }
          privateIPAllocationMethod: 'Static'
          privateIPAddress: '10.20.1.5'
        }
      }
    ]
  }
  dependsOn: [
    hubVnet
    hubVmSubnet
  ]
}

resource hubVm 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: 'za-east-${location}-vm'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: 'za-east-${location}-vm'
      adminUsername: vmAdminUsername
      adminPassword: vmAdminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: hubVmNic.id
        }
      ]
    }
  }
}

resource spokeVmNics 'Microsoft.Network/networkInterfaces@2024-05-01' = [
  for (spoke, index) in spokeConfigs: {
    name: '${spoke.name}-vm-nic'
    location: location
    properties: {
      ipConfigurations: [
        {
          name: 'ipconfig1'
          properties: {
            subnet: {
              id: resourceId('Microsoft.Network/virtualNetworks/subnets', spoke.vnetName, 'Subnet-1')
            }
            privateIPAllocationMethod: 'Static'
            privateIPAddress: spoke.vmPrivateIp
          }
        }
      ]
    }
    dependsOn: [
      spokeVnets
      spokeSubnets
    ]
  }
]

resource spokeVms 'Microsoft.Compute/virtualMachines@2024-03-01' = [
  for (spoke, index) in spokeConfigs: {
    name: '${spoke.name}-vm'
    location: location
    properties: {
      hardwareProfile: {
        vmSize: vmSize
      }
      osProfile: {
        computerName: '${spoke.name}-vm'
        adminUsername: vmAdminUsername
        adminPassword: vmAdminPassword
        linuxConfiguration: {
          disablePasswordAuthentication: false
        }
      }
      storageProfile: {
        imageReference: {
          publisher: 'Canonical'
          offer: '0001-com-ubuntu-server-jammy'
          sku: '22_04-lts-gen2'
          version: 'latest'
        }
        osDisk: {
          createOption: 'FromImage'
          managedDisk: {
            storageAccountType: 'Standard_LRS'
          }
        }
      }
      networkProfile: {
        networkInterfaces: [
          {
            id: spokeVmNics[index].id
          }
        ]
      }
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
output vmNames array = [
  hubVm.name
  spokeVms[0].name
  spokeVms[1].name
  spokeVms[2].name
]
output vmPrivateIps array = [
  hubVmNic.properties.ipConfigurations[0].properties.privateIPAddress
  spokeVmNics[0].properties.ipConfigurations[0].properties.privateIPAddress
  spokeVmNics[1].properties.ipConfigurations[0].properties.privateIPAddress
  spokeVmNics[2].properties.ipConfigurations[0].properties.privateIPAddress
]
output vpnGatewayId string = resourceId('Microsoft.Network/virtualNetworkGateways', vpnGatewayName)
output vpnGatewayPublicIpId string = existingVpnGatewayPublicIp.id
