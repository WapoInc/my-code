targetScope = 'resourceGroup'

@description('Azure region for the Virtual WAN and Virtual Hub.')
param location string = 'southafricanorth'

@description('Name of the Azure Virtual WAN.')
param virtualWanName string = 'Global-vWAN'

@description('Name of the Azure Virtual Hub.')
param virtualHubName string = 'ZAN-Hub-1'

@description('Address prefix assigned to the Azure Virtual Hub.')
param virtualHubAddressPrefix string = '10.200.1.0/24'

@description('Resource tags applied to the Virtual WAN and Virtual Hub.')
param tags object = {}

resource virtualWan 'Microsoft.Network/virtualWans@2024-05-01' = {
  name: virtualWanName
  location: location
  tags: tags
  properties: {
    allowBranchToBranchTraffic: true
    type: 'Standard'
  }
}

resource virtualHub 'Microsoft.Network/virtualHubs@2024-05-01' = {
  name: virtualHubName
  location: location
  tags: tags
  properties: {
    addressPrefix: virtualHubAddressPrefix
    sku: 'Standard'
    virtualWan: {
      id: virtualWan.id
    }
  }
}

output virtualWanId string = virtualWan.id
output virtualHubId string = virtualHub.id

// ----- South Africa North spoke VNet and Ubuntu VM -----

@description('Administrator username for the Ubuntu VM.')
param spokeVmAdminUsername string = 'rootadmin'

@description('Administrator password for the Ubuntu VM.')
@secure()
param spokeVmAdminPassword string

@description('Pre-shared key for the FortiGate site-to-site VPN connection.')
@secure()
param fortiGateVpnSharedKey string

var spokeVnetName = 'ZAN-Spoke-VNet-1'
var spokeSubnetName = 'SubNet-1'
var spokeVmName = 'ZAN-Spoke-VM-1'

resource spokeVnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: spokeVnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.200.5.0/24'
      ]
    }
  }
}

resource spokeSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: spokeVnet
  name: spokeSubnetName
  properties: {
    addressPrefix: '10.200.5.0/25'
  }
}

resource spokeVmNic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: '${spokeVmName}-nic'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: spokeSubnet.id
          }
        }
      }
    ]
  }
}

resource spokeVm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: spokeVmName
  location: location
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B1ls'
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
        deleteOption: 'Delete'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    osProfile: {
      computerName: spokeVmName
      adminUsername: spokeVmAdminUsername
      adminPassword: spokeVmAdminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
        provisionVMAgent: true
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: spokeVmNic.id
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
  }
}

resource spokeVnetHubConnection 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2024-05-01' = {
  parent: virtualHub
  name: '${spokeVnetName}-to-${virtualHubName}'
  properties: {
    enableInternetSecurity: false
    remoteVirtualNetwork: {
      id: spokeVnet.id
    }
  }
}

output spokeVnetId string = spokeVnet.id
output spokeVmId string = spokeVm.id

// ----- End South Africa North spoke VNet and Ubuntu VM -----

// ----- South Africa North spoke VNet 2 and Ubuntu VM -----

var spokeVnet2Name = 'ZAN-Spoke-VNet-2'
var spokeSubnet2Name = 'SubNet-1'
var spokeVm2Name = 'ZAN-Spoke-VM-2'

resource spokeVnet2 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: spokeVnet2Name
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.200.6.0/24'
      ]
    }
  }
}

resource spokeSubnet2 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: spokeVnet2
  name: spokeSubnet2Name
  properties: {
    addressPrefix: '10.200.6.0/25'
  }
}

resource spokeVm2Nic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: '${spokeVm2Name}-nic'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: spokeSubnet2.id
          }
        }
      }
    ]
  }
}

resource spokeVm2 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: spokeVm2Name
  location: location
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B1ls'
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
        deleteOption: 'Delete'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    osProfile: {
      computerName: spokeVm2Name
      adminUsername: spokeVmAdminUsername
      adminPassword: spokeVmAdminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
        provisionVMAgent: true
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: spokeVm2Nic.id
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
  }
}

resource spokeVnet2HubConnection 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2024-05-01' = {
  parent: virtualHub
  name: '${spokeVnet2Name}-to-${virtualHubName}'
  properties: {
    enableInternetSecurity: false
    remoteVirtualNetwork: {
      id: spokeVnet2.id
    }
  }
}

output spokeVnet2Id string = spokeVnet2.id
output spokeVm2Id string = spokeVm2.id

// ----- End South Africa North spoke VNet 2 and Ubuntu VM -----

// ----- South Africa North vWAN ExpressRoute gateway and ER-Metro connection -----

var expressRouteGatewayName = 'ZAN-Hub-ER-Gateway'
var expressRouteConnectionName = 'ER-Metro-to-ZAN-Hub'

resource erMetroCircuit 'Microsoft.Network/expressRouteCircuits@2024-05-01' existing = {
  scope: resourceGroup(subscription().subscriptionId, 'ER-LTSA-rg')
  name: 'ER-Metro'
}

resource erMetroPrivatePeering 'Microsoft.Network/expressRouteCircuits/peerings@2024-05-01' existing = {
  parent: erMetroCircuit
  name: 'AzurePrivatePeering'
}

resource expressRouteGateway 'Microsoft.Network/expressRouteGateways@2024-05-01' = {
  name: expressRouteGatewayName
  location: location
  tags: tags
  properties: {
    autoScaleConfiguration: {
      bounds: {
        min: 1
        max: 1
      }
    }
    virtualHub: {
      id: virtualHub.id
    }
  }
}

resource erMetroConnection 'Microsoft.Network/expressRouteGateways/expressRouteConnections@2024-05-01' = {
  parent: expressRouteGateway
  name: expressRouteConnectionName
  properties: {
    enableInternetSecurity: false
    expressRouteCircuitPeering: {
      id: erMetroPrivatePeering.id
    }
    routingWeight: 0
  }
}

output expressRouteGatewayId string = expressRouteGateway.id
output erMetroConnectionId string = erMetroConnection.id

// ----- End South Africa North vWAN ExpressRoute gateway and ER-Metro connection -----

// ----- South Africa North vWAN VPN gateway and FortiGate connection -----

var vpnGatewayName = 'ZAN-Hub-VPN-Gateway'
var fortiGateVpnSiteName = 'MiaCasa-Fort-1'
var fortiGateVpnSiteLinkName = fortiGateVpnSiteName
var fortiGateVpnConnectionName = 'MiaCasa-Fort-1-to-ZAN-Hub'

resource fortiGateVpnSite 'Microsoft.Network/vpnSites@2024-05-01' = {
  name: fortiGateVpnSiteName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        '192.168.2.0/24'
      ]
    }
    deviceProperties: {
      deviceVendor: 'Fortinet'
      deviceModel: 'FortiGate'
      linkSpeedInMbps: 100
    }
    virtualWan: {
      id: virtualWan.id
    }
    vpnSiteLinks: [
      {
        name: fortiGateVpnSiteLinkName
        properties: {
          ipAddress: '156.155.28.158'
          linkProperties: {
            linkProviderName: 'MiaCasa'
            linkSpeedInMbps: 100
          }
        }
      }
    ]
  }
}

resource vpnGateway 'Microsoft.Network/vpnGateways@2024-05-01' = {
  name: vpnGatewayName
  location: location
  tags: tags
  properties: {
    virtualHub: {
      id: virtualHub.id
    }
    vpnGatewayScaleUnit: 1
  }
}

resource defaultHubRouteTable 'Microsoft.Network/virtualHubs/hubRouteTables@2024-05-01' existing = {
  parent: virtualHub
  name: 'defaultRouteTable'
}

resource fortiGateVpnConnection 'Microsoft.Network/vpnGateways/vpnConnections@2024-05-01' = {
  parent: vpnGateway
  name: fortiGateVpnConnectionName
  properties: {
    enableInternetSecurity: false
    remoteVpnSite: {
      id: fortiGateVpnSite.id
    }
    routingConfiguration: {
      associatedRouteTable: {
        id: defaultHubRouteTable.id
      }
      propagatedRouteTables: {
        ids: [
          {
            id: defaultHubRouteTable.id
          }
        ]
        labels: [
          'default'
        ]
      }
    }
    vpnLinkConnections: [
      {
        name: fortiGateVpnSiteLinkName
        properties: {
          connectionBandwidth: 100
          dpdTimeoutSeconds: 20
          enableBgp: false
          sharedKey: fortiGateVpnSharedKey
          usePolicyBasedTrafficSelectors: false
          vpnConnectionProtocolType: 'IKEv2'
          vpnSiteLink: {
            id: '${fortiGateVpnSite.id}/vpnSiteLinks/${fortiGateVpnSiteLinkName}'
          }
        }
      }
    ]
  }
}

output vpnGatewayId string = vpnGateway.id
output vpnGatewayPublicIpAddresses string[] = [
  vpnGateway.properties.ipConfigurations[0].publicIpAddress
  vpnGateway.properties.ipConfigurations[1].publicIpAddress
]
output fortiGateVpnSiteId string = fortiGateVpnSite.id
output fortiGateVpnConnectionId string = fortiGateVpnConnection.id

// ----- End South Africa North vWAN VPN gateway and FortiGate connection -----
