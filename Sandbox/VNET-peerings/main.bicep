// Creates a hub with a VPN gateway, a FortiGate site-to-site connection,
// spoke 5/6 peerings using gateway transit, and one Ubuntu VM per VNet.

targetScope = 'resourceGroup'

@description('Azure region for the hub, spokes, and VPN gateway.')
param location string = 'southafricanorth'

@description('Name of the new hub virtual network that hosts the VPN gateway.')
param hubVnetName string = 'hub'
param hubVnetPrefix string = '10.26.0.0/24'
param hubGatewaySubnetPrefix string = '10.26.0.0/27'
param hubSubnetName string = 'Subnet-1'
param hubSubnetPrefix string = '10.26.0.64/26'

@description('Public IP address of the on-premises FortiGate.')
param onPremGatewayIpAddress string = '156.155.28.158'

@description('On-premises network reachable through the FortiGate.')
param onPremAddressPrefix string = '192.168.2.0/24'

@secure()
@minLength(1)
@description('IPsec pre-shared key matching the FortiGate, supplied by a Key Vault parameter reference in deploy-bicep.sh.')
param vpnSharedKey string

param vmAdminUsername string = 'rootadmin'
param vmSize string = 'Standard_B1ls'

@secure()
@minLength(12)
@maxLength(72)
@description('VM administrator password, supplied by a separate Key Vault secret in deploy-bicep.sh.')
param vmAdminPassword string

param spoke5VnetName string = 'za-east-spoke-5-vnet'
param spoke5VnetPrefix string = '10.24.0.0/24'
param spoke5SubnetName string = 'Subnet-1'
param spoke5SubnetPrefix string = '10.24.0.0/25'

param spoke6VnetName string = 'za-east-spoke-6-vnet'
param spoke6VnetPrefix string = '10.25.0.0/24'
param spoke6SubnetName string = 'Subnet-1'
param spoke6SubnetPrefix string = '10.25.0.0/25'

param hubToSpoke5PeeringName string = 'hub-to-za-east-spoke-5'
param spoke5ToHubPeeringName string = 'za-east-spoke-5-to-hub'
param hubToSpoke6PeeringName string = 'hub-to-za-east-spoke-6'
param spoke6ToHubPeeringName string = 'za-east-spoke-6-to-hub'

resource hubVnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: hubVnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        hubVnetPrefix
      ]
    }
    subnets: [
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: hubGatewaySubnetPrefix
        }
      }
      {
        name: hubSubnetName
        properties: {
          addressPrefix: hubSubnetPrefix
        }
      }
    ]
  }
}

resource hubGatewayPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: '${hubVnetName}-vpngw-pip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

resource hubVpnGateway 'Microsoft.Network/virtualNetworkGateways@2024-05-01' = {
  name: '${hubVnetName}-vpngw'
  location: location
  properties: {
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    vpnGatewayGeneration: 'Generation1'
    sku: {
      name: 'VpnGw1AZ'
      tier: 'VpnGw1AZ'
    }
    activeActive: false
    enableBgp: false
    ipConfigurations: [
      {
        name: 'gateway-ipconfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: hubGatewayPublicIp.id
          }
          subnet: {
            id: '${hubVnet.id}/subnets/GatewaySubnet'
          }
        }
      }
    ]
  }
}

resource onPremLocalNetworkGateway 'Microsoft.Network/localNetworkGateways@2024-05-01' = {
  name: '${hubVnetName}-lng-fortigate'
  location: location
  properties: {
    gatewayIpAddress: onPremGatewayIpAddress
    localNetworkAddressSpace: {
      addressPrefixes: [
        onPremAddressPrefix
      ]
    }
  }
}

resource onPremVpnConnection 'Microsoft.Network/connections@2024-05-01' = {
  name: '${hubVnetName}-to-fortigate'
  location: location
  properties: {
    connectionType: 'IPsec'
    connectionProtocol: 'IKEv2'
    virtualNetworkGateway1: {
      id: hubVpnGateway.id
      properties: {}
    }
    localNetworkGateway2: {
      id: onPremLocalNetworkGateway.id
      properties: {}
    }
    sharedKey: vpnSharedKey
    enableBgp: false
    usePolicyBasedTrafficSelectors: false
    ipsecPolicies: [
      {
        ikeEncryption: 'AES256'
        ikeIntegrity: 'SHA256'
        dhGroup: 'DHGroup14'
        ipsecEncryption: 'AES256'
        ipsecIntegrity: 'SHA256'
        pfsGroup: 'None'
        saLifeTimeSeconds: 27000
        saDataSizeKilobytes: 102400000
      }
    ]
  }
}

resource spoke5Vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: spoke5VnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        spoke5VnetPrefix
      ]
    }
    subnets: [
      {
        name: spoke5SubnetName
        properties: {
          addressPrefix: spoke5SubnetPrefix
        }
      }
    ]
  }
}

resource spoke6Vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: spoke6VnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        spoke6VnetPrefix
      ]
    }
    subnets: [
      {
        name: spoke6SubnetName
        properties: {
          addressPrefix: spoke6SubnetPrefix
        }
      }
    ]
  }
}

// Hub side advertises the VPN gateway to the spoke.
resource hubToSpoke5 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = {
  parent: hubVnet
  name: hubToSpoke5PeeringName
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: true
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: spoke5Vnet.id
    }
  }
}

// Spoke side consumes the hub remote gateway; it must follow the hub transit peering.
resource spoke5ToHub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = {
  parent: spoke5Vnet
  name: spoke5ToHubPeeringName
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: true
    remoteVirtualNetwork: {
      id: hubVnet.id
    }
  }
  dependsOn: [
    hubToSpoke5
    hubVpnGateway
  ]
}

resource hubToSpoke6 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = {
  parent: hubVnet
  name: hubToSpoke6PeeringName
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: true
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: spoke6Vnet.id
    }
  }
  // Serialize hub-side peering writes to avoid superseded operations on the hub VNet.
  dependsOn: [
    hubToSpoke5
  ]
}

resource spoke6ToHub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = {
  parent: spoke6Vnet
  name: spoke6ToHubPeeringName
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: true
    remoteVirtualNetwork: {
      id: hubVnet.id
    }
  }
  dependsOn: [
    hubToSpoke6
    hubVpnGateway
  ]
}

var vmDefinitions = [
  {
    name: 'hub-vm'
    subnetId: '${hubVnet.id}/subnets/${hubSubnetName}'
  }
  {
    name: 'spoke5-vm'
    subnetId: '${spoke5Vnet.id}/subnets/${spoke5SubnetName}'
  }
  {
    name: 'spoke6-vm'
    subnetId: '${spoke6Vnet.id}/subnets/${spoke6SubnetName}'
  }
]

resource vmNetworkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: '${hubVnetName}-vm-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowSshFromOnPrem'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefixes: [
            '${onPremGatewayIpAddress}/32'
            onPremAddressPrefix
          ]
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
    ]
  }
}

resource vmPublicIps 'Microsoft.Network/publicIPAddresses@2024-05-01' = [for vm in vmDefinitions: {
  name: '${vm.name}-pip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}]

resource vmNics 'Microsoft.Network/networkInterfaces@2024-05-01' = [for (vm, i) in vmDefinitions: {
  name: '${vm.name}-nic'
  location: location
  properties: {
    networkSecurityGroup: {
      id: vmNetworkSecurityGroup.id
    }
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: vm.subnetId
          }
          publicIPAddress: {
            id: vmPublicIps[i].id
          }
        }
      }
    ]
  }
}]

resource virtualMachines 'Microsoft.Compute/virtualMachines@2024-07-01' = [for (vm, i) in vmDefinitions: {
  name: vm.name
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vm.name
      adminUsername: vmAdminUsername
      adminPassword: vmAdminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
        provisionVMAgent: true
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
        diskSizeGB: 30
        caching: 'ReadWrite'
        deleteOption: 'Delete'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: vmNics[i].id
          properties: {
            primary: true
            deleteOption: 'Delete'
          }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}]

output hubVnetId string = hubVnet.id
output spoke5VnetId string = spoke5Vnet.id
output spoke6VnetId string = spoke6Vnet.id
output hubVpnGatewayId string = hubVpnGateway.id
output hubVpnGatewayPublicIpAddress string = hubGatewayPublicIp.properties.ipAddress
output onPremLocalNetworkGatewayId string = onPremLocalNetworkGateway.id
output onPremVpnConnectionId string = onPremVpnConnection.id
output vmConnectionDetails array = [for (vm, i) in vmDefinitions: {
  name: vm.name
  username: vmAdminUsername
  publicIpAddress: vmPublicIps[i].properties.ipAddress
  privateIpAddress: vmNics[i].properties.ipConfigurations[0].properties.privateIPAddress
}]
