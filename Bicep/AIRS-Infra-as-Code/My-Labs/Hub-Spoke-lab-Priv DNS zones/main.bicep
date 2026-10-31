// ============================================================
// Hub + 3 Spokes lab - VNets, bidirectional peering, 4 VMs,
// and a private DNS zone with an A record per VM.
// ExpressRoute connects the hub and all spokes to the existing circuit.
// Resource-group scoped. Region: South Africa North.
// ============================================================

targetScope = 'resourceGroup'

@description('Azure region for all resources.')
param location string = 'southafricanorth'

@description('Admin username for every VM.')
param adminUsername string = 'rootadmin'

@secure()
@description('Admin password for every VM (password auth).')
param adminPassword string

@description('VM size (SKU).')
param vmSize string = 'Standard_B2s'

@description('Private DNS zone that holds an A record per VM.')
param privateDnsZoneName string = 'lab.internal'

@description('Existing circuit with provisioned Azure private peering. The circuit is not modified.')
param expressRouteCircuitId string = '/subscriptions/0cfd0d2a-2b38-4c93-ba14-cf79185bc683/resourceGroups/ER-LTSA-rg/providers/Microsoft.Network/expressRouteCircuits/ER-LIT-ZAN'

@description('Dedicated hub GatewaySubnet, without an NSG; must not overlap subnet-1.')
param gatewaySubnetPrefix string = '10.30.0.128/27'

@allowed([
  'ErGw1AZ'
  'ErGw2AZ'
  'ErGw3AZ'
])
param expressRouteGatewaySku string = 'ErGw1AZ'

type vnetConfig = {
  @description('Virtual network name.')
  name: string
  @description('VNet address space (/24).')
  cidr: string
  @description('subnet-1 prefix (/25).')
  subnetCidr: string
  @description('VM name and DNS host label.')
  vmName: string
  @description('Static private IP for the VM NIC (also the A record value).')
  vmIp: string
  @description('True for the hub network.')
  isHub: bool
}

// Index 0 is the hub; indexes 1-3 are the spokes.
var networks vnetConfig[] = [
  {
    name: 'hub-vnet'
    cidr: '10.30.0.0/24'
    subnetCidr: '10.30.0.0/25'
    vmName: 'hub-vm'
    vmIp: '10.30.0.4'
    isHub: true
  }
  {
    name: 'spoke1-vnet'
    cidr: '10.31.0.0/24'
    subnetCidr: '10.31.0.0/25'
    vmName: 'spoke1-vm'
    vmIp: '10.31.0.4'
    isHub: false
  }
  {
    name: 'spoke2-vnet'
    cidr: '10.32.0.0/24'
    subnetCidr: '10.32.0.0/25'
    vmName: 'spoke2-vm'
    vmIp: '10.32.0.4'
    isHub: false
  }
  {
    name: 'spoke3-vnet'
    cidr: '10.33.0.0/24'
    subnetCidr: '10.33.0.0/25'
    vmName: 'spoke3-vm'
    vmIp: '10.33.0.4'
    isHub: false
  }
]

var subnetName = 'subnet-1'
var spokeIndexes = [1, 2, 3]

var imageReference = {
  publisher: 'Canonical'
  offer: '0001-com-ubuntu-server-jammy'
  sku: '22_04-lts-gen2'
  version: 'latest'
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: 'hub-spokes-lab-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-SSH'
        properties: {
          priority: 1000
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
      {
        name: 'Allow-ICMP-VNet'
        properties: {
          priority: 1010
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Icmp'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

resource vnets 'Microsoft.Network/virtualNetworks@2023-11-01' = [
  for net in networks: {
    name: net.name
    location: location
    properties: {
      addressSpace: {
        addressPrefixes: [
          net.cidr
        ]
      }
      subnets: concat([
        {
          name: subnetName
          properties: {
            addressPrefix: net.subnetCidr
            networkSecurityGroup: {
              id: nsg.id
            }
          }
        }
      ], net.isHub ? [
        {
          name: 'GatewaySubnet'
          properties: {
            addressPrefix: gatewaySubnetPrefix
          }
        }
      ] : [])
    }
  }
]

@batchSize(1)
resource hubToSpoke 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-11-01' = [
  for i in spokeIndexes: {
    parent: vnets[0]
    name: 'hub-to-${networks[i].name}'
    properties: {
      allowVirtualNetworkAccess: true
      allowForwardedTraffic: true
      allowGatewayTransit: true
      useRemoteGateways: false
      remoteVirtualNetwork: {
        id: vnets[i].id
      }
    }
  }
]

resource spokeToHub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-11-01' = [
  for i in spokeIndexes: {
    parent: vnets[i]
    name: '${networks[i].name}-to-hub'
    properties: {
      allowVirtualNetworkAccess: true
      allowForwardedTraffic: true
      allowGatewayTransit: false
      useRemoteGateways: true
      remoteVirtualNetwork: {
        id: vnets[0].id
      }
    }
    dependsOn: [
      hubToSpoke
      expressRouteGateway
    ]
  }
]

resource expressRoutePublicIp 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: 'hub-ergw-pip'
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

resource expressRouteGateway 'Microsoft.Network/virtualNetworkGateways@2024-05-01' = {
  name: 'hub-ergw'
  location: location
  properties: {
    gatewayType: 'ExpressRoute'
    vpnType: 'RouteBased'
    sku: {
      name: expressRouteGatewaySku
      tier: expressRouteGatewaySku
    }
    ipConfigurations: [
      {
        name: 'gateway-ipconfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: expressRoutePublicIp.id
          }
          subnet: {
            id: '${vnets[0].id}/subnets/GatewaySubnet'
          }
        }
      }
    ]
  }
}

resource expressRouteConnection 'Microsoft.Network/connections@2024-05-01' = {
  name: 'hub-ergw-to-er-lit-zan'
  location: location
  properties: {
    connectionType: 'ExpressRoute'
    virtualNetworkGateway1: {
      id: expressRouteGateway.id
      properties: {}
    }
    peer: {
      id: expressRouteCircuitId
    }
    routingWeight: 0
  }
}

resource publicIps 'Microsoft.Network/publicIPAddresses@2023-11-01' = [
  for net in networks: {
    name: '${net.vmName}-pip'
    location: location
    sku: {
      name: 'Standard'
    }
    properties: {
      publicIPAllocationMethod: 'Static'
    }
  }
]

resource nics 'Microsoft.Network/networkInterfaces@2023-11-01' = [
  for (net, i) in networks: {
    name: '${net.vmName}-nic'
    location: location
    properties: {
      ipConfigurations: [
        {
          name: 'ipconfig1'
          properties: {
            subnet: {
              id: '${vnets[i].id}/subnets/${subnetName}'
            }
            privateIPAllocationMethod: 'Static'
            privateIPAddress: net.vmIp
            publicIPAddress: {
              id: publicIps[i].id
            }
          }
        }
      ]
    }
  }
]

resource vms 'Microsoft.Compute/virtualMachines@2024-03-01' = [
  for (net, i) in networks: {
    name: net.vmName
    location: location
    properties: {
      hardwareProfile: {
        vmSize: vmSize
      }
      osProfile: {
        computerName: net.vmName
        adminUsername: adminUsername
        adminPassword: adminPassword
        linuxConfiguration: {
          disablePasswordAuthentication: false
        }
      }
      storageProfile: {
        imageReference: imageReference
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
            id: nics[i].id
          }
        ]
      }
      diagnosticsProfile: {
        bootDiagnostics: {
          enabled: true
        }
      }
    }
  }
]

resource dnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateDnsZoneName
  location: 'global'
}

resource dnsLinks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = [
  for (net, i) in networks: {
    parent: dnsZone
    name: 'link-${net.name}'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: vnets[i].id
      }
    }
  }
]

resource dnsARecords 'Microsoft.Network/privateDnsZones/A@2020-06-01' = [
  for net in networks: {
    parent: dnsZone
    name: net.vmName
    properties: {
      ttl: 3600
      aRecords: [
        {
          ipv4Address: net.vmIp
        }
      ]
    }
  }
]

output vnetNames array = [for (net, i) in networks: vnets[i].name]
output vmPrivateIps array = [for net in networks: net.vmIp]
output vmPublicIps array = [for (net, i) in networks: publicIps[i].properties.ipAddress]
output vmFqdns array = [for net in networks: '${net.vmName}.${privateDnsZoneName}']
output expressRouteGatewayId string = expressRouteGateway.id
output expressRouteConnectionId string = expressRouteConnection.id
output hubGatewaySubnetPrefix string = gatewaySubnetPrefix
