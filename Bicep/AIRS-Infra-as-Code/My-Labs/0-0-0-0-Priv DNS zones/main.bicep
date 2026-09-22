// ============================================================
// Hub + 3 Spokes lab - VNets, bidirectional peering, 4 VMs,
// and a private DNS zone with an A record per VM.
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
      subnets: [
        {
          name: subnetName
          properties: {
            addressPrefix: net.subnetCidr
            networkSecurityGroup: {
              id: nsg.id
            }
          }
        }
      ]
    }
  }
]

resource hubToSpoke 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-11-01' = [
  for i in spokeIndexes: {
    parent: vnets[0]
    name: 'hub-to-${networks[i].name}'
    properties: {
      allowVirtualNetworkAccess: true
      allowForwardedTraffic: true
      allowGatewayTransit: false
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
      useRemoteGateways: false
      remoteVirtualNetwork: {
        id: vnets[0].id
      }
    }
  }
]

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
