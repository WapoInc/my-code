// Creates a hub with an ExpressRoute gateway and circuit connection,
// spoke 5/6 peerings using gateway transit, and one Ubuntu VM per VNet.

targetScope = 'resourceGroup'

@description('Azure region for the hub, spokes, and gateways.')
param location string = 'southafricanorth'

@description('Name of the hub virtual network that hosts the ExpressRoute gateway.')
param hubVnetName string = 'hub'
param hubVnetPrefix string = '10.26.0.0/24'
param hubGatewaySubnetPrefix string = '10.26.0.0/27'
param hubSubnetName string = 'Subnet-1'
param hubSubnetPrefix string = '10.26.0.64/26'

@description('Existing ExpressRoute circuit with provisioned Azure private peering. The circuit is not modified.')
param expressRouteCircuitId string = '/subscriptions/0cfd0d2a-2b38-4c93-ba14-cf79185bc683/resourceGroups/ER-LTSA-rg/providers/Microsoft.Network/expressRouteCircuits/ER-LIT-ZAN'

@description('On-premises public IP permitted to SSH to the VM public IPs.')
param onPremGatewayIpAddress string = '156.155.28.158'

@description('On-premises network advertised over ExpressRoute and permitted for VM SSH.')
param onPremAddressPrefix string = '172.22.1.0/24'

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

resource hubExpressRoutePublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: '${hubVnetName}-ergw-pip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

resource hubExpressRouteGateway 'Microsoft.Network/virtualNetworkGateways@2024-05-01' = {
  name: '${hubVnetName}-ergw'
  location: location
  properties: {
    gatewayType: 'ExpressRoute'
    vpnType: 'RouteBased'
    sku: {
      name: 'ErGw1AZ'
      tier: 'ErGw1AZ'
    }
    ipConfigurations: [
      {
        name: 'gateway-ipconfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: hubExpressRoutePublicIp.id
          }
          subnet: {
            id: '${hubVnet.id}/subnets/GatewaySubnet'
          }
        }
      }
    ]
  }
}

resource hubExpressRouteConnection 'Microsoft.Network/connections@2024-05-01' = {
  name: '${hubVnetName}-to-expressroute'
  location: location
  properties: {
    connectionType: 'ExpressRoute'
    virtualNetworkGateway1: {
      id: hubExpressRouteGateway.id
      properties: {}
    }
    peer: {
      id: expressRouteCircuitId
    }
    routingWeight: 0
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

// Hub side advertises gateway transit to the spoke.
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
    hubExpressRouteGateway
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
    hubExpressRouteGateway
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
output hubExpressRouteGatewayId string = hubExpressRouteGateway.id
output hubExpressRouteConnectionId string = hubExpressRouteConnection.id
output fortigateConfiguration object = {
  onPremPrefix: onPremAddressPrefix
  hubPrefix: hubVnetPrefix
  spoke5Prefix: spoke5VnetPrefix
  spoke6Prefix: spoke6VnetPrefix
}
output vmConnectionDetails array = [for (vm, i) in vmDefinitions: {
  name: vm.name
  username: vmAdminUsername
  publicIpAddress: vmPublicIps[i].properties.ipAddress
  privateIpAddress: vmNics[i].properties.ipConfigurations[0].properties.privateIPAddress
}]
