// ============================================================
// ZA-East-HUB resources - VNet + Subnets + optional VPN Gateway + VM
// South Africa North  |  v5 - Bicep (resource-group scoped module)
// ============================================================
// Called by the subscription-scoped orchestrator
// (ZAN-Hub-VM-vnet-er-gw-v5-rg.bicep), which creates the
// resource group and invokes this module.
// vmr
// NOTE: A VPN gateway typically takes 20-45 minutes to provision.
// ============================================================

targetScope = 'resourceGroup'

// --- Parameters ---------------------------------------------
@description('Azure region for all resources.')
param location string = 'southafricanorth'

param vnetName string = 'za-east-${location}-vnet'
param vnetPrefix string = '10.20.0.0/20'

var prefixedVnetName = startsWith(toLower(vnetName), 'za-east-') ? vnetName : 'za-east-${vnetName}'

param subnet1Name string = 'ZA-East-Hub'
param nsgName string = 'za-east-${location}-default-nsg'

@allowed([
  'None'
  'VpnGw1AZ'
  'VpnGw2AZ'
  'VpnGw3AZ'
  'VpnGw4AZ'
  'VpnGw5AZ'
])
@description('VPN gateway SKU to deploy. Select None to skip the VPN gateway and its public IP.')
param vpnGatewaySku string = 'None'

@allowed([
  'None'
  'Basic'
  'Standard'
  'Premium'
])
@description('Azure Firewall tier to deploy. Select None to skip Azure Firewall and its public IP resources.')
param azureFirewallSku string = 'None'

param azureFirewallName string = 'AzFW-ZA-East-${location}'
param azureFirewallPolicyName string = '${azureFirewallName}-Policy'
param azureFirewallPublicIpName string = '${azureFirewallName}-pip'
param azureFirewallManagementPublicIpName string = '${azureFirewallName}-mgmt-pip'

param vpnGatewayName string = 'za-east-VPN-Gateway-${location}-${vpnGatewaySku}'
param vpnGatewayPipName string = 'za-east-VPN-Gateway-${location}-${vpnGatewaySku}-zones123-pip'

var deployVpnGateway = vpnGatewaySku != 'None'
var prefixedVpnGatewayName = startsWith(toLower(vpnGatewayName), 'za-east-') ? vpnGatewayName : 'za-east-${vpnGatewayName}'

@description('Public IP address of the on-premises FortiGate VPN endpoint.')
param fortiGatePublicIp string = '156.155.28.158'

@description('On-premises CIDR prefixes reachable through the FortiGate VPN.')
param onPremisesAddressPrefixes array = [
  '192.168.2.0/24'
]

@description('BGP ASN used by the on-premises FortiGate.')
param fortiGateBgpAsn int = 65521

@description('BGP peer IP address configured on the on-premises FortiGate.')
param fortiGateBgpPeerIp string = '66.66.66.66'

@description('BGP ASN used by the Azure VPN gateway.')
param azureVpnBgpAsn int = 65515

@description('Enable BGP on the Azure VPN gateway, local network gateway, and connection.')
param enableFortiGateBgp bool = true

@description('Create the FortiGate local network gateway.')
param createFortiGateLocalNetworkGateway bool = false

var deployFortiGateConnection = createFortiGateLocalNetworkGateway && deployVpnGateway
var deployAzureFirewall = azureFirewallSku != 'None'
var deployAzureFirewallManagementIp = azureFirewallSku == 'Basic'
var fortiGateLocalNetworkGatewayName = 'za-east-LNG-MiaCasa'
var fortiGateConnectionName = '${prefixedVpnGatewayName}-to-FortiGate'

param vmName string = 'za-east-${location}-JB-1'
param vmNicName string = '${vmName}-nic'
param vmSize string = 'Standard_B2s'
param vmPrivateIp string = '10.20.1.5'
param adminUsername string = 'rootadmin'

@secure()
param adminPassword string

@description('Smallest general-purpose VM size for the spoke jump-box VMs.')
param spokeVmSize string = 'Standard_B1ls'

var spokeConfigs = [
  {
    name: 'za-east-spoke-1'
    vnetPrefix: '10.21.0.0/20'
    subnetPrefix: '10.21.1.0/25'
    vmPrivateIp: '10.21.1.5'
  }
  {
    name: 'za-east-spoke-2'
    vnetPrefix: '10.22.0.0/20'
    subnetPrefix: '10.22.1.0/25'
    vmPrivateIp: '10.22.1.5'
  }
  {
    name: 'za-east-spoke-3'
    vnetPrefix: '10.23.0.0/20'
    subnetPrefix: '10.23.1.0/25'
    vmPrivateIp: '10.23.1.5'
  }
]

var spokeVnetPrefixes = [for spoke in spokeConfigs: spoke.vnetPrefix]
var azureVnetPrefixes = union([
  vnetPrefix
], spokeVnetPrefixes)
var protectedNetworkPrefixes = union([
  vnetPrefix
], spokeVnetPrefixes, onPremisesAddressPrefixes)
var internetDefaultPrefix = '0.0.0.0/0'
var hubRoutePrefixes = union(spokeVnetPrefixes, onPremisesAddressPrefixes, [
  internetDefaultPrefix
])
var gatewayReturnPrefixes = union([
  vnetPrefix
], spokeVnetPrefixes)

// --- ZA-East subnet address prefixes ------------------------
var gatewaySubnetPrefix = '10.20.0.0/24'
var hubSubnetPrefix = '10.20.1.0/24'
var bastionSubnetPrefix = '10.20.2.0/26'
var dnsInboundSubnetPrefix = '10.20.2.64/28'
var dnsOutboundSubnetPrefix = '10.20.2.80/28'
var subnet1Prefix = '10.20.3.0/24'
var subnet2Prefix = '10.20.5.0/24'
var privateEndpointSubnetPrefix = '10.20.6.0/27'
var firewallSubnetPrefix = '10.20.6.64/26'
var firewallMgmtSubnetPrefix = '10.20.7.0/24'
var pingTestSubnetPrefix = '10.20.8.0/24'
var appGwSubnetPrefix = '10.20.9.0/24'
var cloudShellSubnetPrefix = '10.20.10.0/24'

// --- Default NSG (Azure built-in rules only) ----------------
resource nsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: []
  }
}

// --- Zone-redundant public IP for the VPN Gateway -----------
resource gwPip 'Microsoft.Network/publicIPAddresses@2023-11-01' = if (deployVpnGateway) {
  name: vpnGatewayPipName
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

resource azureFirewallPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = if (deployAzureFirewall) {
  name: azureFirewallPublicIpName
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

resource azureFirewallManagementPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = if (deployAzureFirewallManagementIp) {
  name: azureFirewallManagementPublicIpName
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

// --- VNet with all hub subnets ------------------------------
resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: prefixedVnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetPrefix
      ]
    }
    subnets: [
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: gatewaySubnetPrefix
        }
      }
      {
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: firewallSubnetPrefix
        }
      }
      {
        name: 'AzureFirewallManagementSubnet'
        properties: {
          addressPrefix: firewallMgmtSubnetPrefix
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: bastionSubnetPrefix
        }
      }
      {
        name: subnet1Name
        properties: {
          addressPrefix: hubSubnetPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
      {
        name: 'ZA-East-Subnet-1'
        properties: {
          addressPrefix: subnet1Prefix
        }
      }
      {
        name: 'ZA-East-Subnet-2'
        properties: {
          addressPrefix: subnet2Prefix
        }
      }
      {
        name: 'PEP'
        properties: {
          addressPrefix: privateEndpointSubnetPrefix
        }
      }
      {
        name: 'InBound-EP'
        properties: {
          addressPrefix: dnsInboundSubnetPrefix
          delegations: [
            {
              name: 'Microsoft.Network.dnsResolvers'
              properties: {
                serviceName: 'Microsoft.Network/dnsResolvers'
              }
            }
          ]
        }
      }
      {
        name: 'OutBound-EP1'
        properties: {
          addressPrefix: dnsOutboundSubnetPrefix
          delegations: [
            {
              name: 'Microsoft.Network.dnsResolvers'
              properties: {
                serviceName: 'Microsoft.Network/dnsResolvers'
              }
            }
          ]
        }
      }
      {
        name: 'Ping-test'
        properties: {
          addressPrefix: pingTestSubnetPrefix
        }
      }
      {
        name: 'AppGW-SubNet'
        properties: {
          addressPrefix: appGwSubnetPrefix
        }
      }
      {
        name: 'CloudShell'
        properties: {
          addressPrefix: cloudShellSubnetPrefix
        }
      }
    ]
  }
}

// --- VPN Gateway --------------------------------------------
resource vpnGateway 'Microsoft.Network/virtualNetworkGateways@2023-11-01' = if (deployVpnGateway) {
  name: prefixedVpnGatewayName
  location: location
  properties: {
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    activeActive: false
    enableBgp: enableFortiGateBgp
    bgpSettings: enableFortiGateBgp ? {
      asn: azureVpnBgpAsn
    } : null
    sku: {
      name: vpnGatewaySku
      tier: vpnGatewaySku
    }
    ipConfigurations: [
      {
        name: 'gwipconfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${vnet.id}/subnets/GatewaySubnet'
          }
          publicIPAddress: {
            id: resourceId('Microsoft.Network/publicIPAddresses', vpnGatewayPipName)
          }
        }
      }
    ]
  }
  dependsOn: [
    gwPip
  ]
}

resource azureFirewallPolicy 'Microsoft.Network/firewallPolicies@2024-05-01' = if (deployAzureFirewall) {
  name: azureFirewallPolicyName
  location: location
  properties: {
    sku: {
      tier: azureFirewallSku
    }
    threatIntelMode: 'Alert'
  }
}

resource azureFirewallPolicyRules 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2024-05-01' = if (deployAzureFirewall) {
  parent: azureFirewallPolicy
  name: 'Allow-Private-Any-RCG'
  properties: {
    priority: 200
    ruleCollections: [
      {
        name: 'Allow-Private-Any'
        priority: 200
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        action: {
          type: 'Allow'
        }
        rules: [
          {
            name: 'Allow-Hub-Spokes-OnPrem-Any'
            ruleType: 'NetworkRule'
            ipProtocols: [
              'Any'
            ]
            sourceAddresses: protectedNetworkPrefixes
            destinationAddresses: protectedNetworkPrefixes
            destinationPorts: [
              '*'
            ]
          }
        ]
      }
      {
        name: 'Allow-Internet-Web'
        priority: 300
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        action: {
          type: 'Allow'
        }
        rules: [
          {
            name: 'Allow-All-Subnets-HTTP-HTTPS'
            ruleType: 'ApplicationRule'
            sourceAddresses: azureVnetPrefixes
            protocols: [
              {
                protocolType: 'Http'
                port: 80
              }
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            targetFqdns: [
              '*'
            ]
          }
        ]
      }
    ]
  }
}

resource azureFirewall 'Microsoft.Network/azureFirewalls@2024-05-01' = if (deployAzureFirewall) {
  name: azureFirewallName
  location: location
  zones: [
    '1'
    '2'
    '3'
  ]
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: azureFirewallSku
    }
    threatIntelMode: 'Alert'
    firewallPolicy: {
      id: azureFirewallPolicy.id
    }
    ipConfigurations: [
      {
        name: '${azureFirewallName}-ipconfig'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', prefixedVnetName, 'AzureFirewallSubnet')
          }
          publicIPAddress: {
            id: resourceId('Microsoft.Network/publicIPAddresses', azureFirewallPublicIpName)
          }
        }
      }
    ]
    managementIpConfiguration: deployAzureFirewallManagementIp ? {
      name: '${azureFirewallName}-management-ipconfig'
      properties: {
        subnet: {
          id: resourceId('Microsoft.Network/virtualNetworks/subnets', prefixedVnetName, 'AzureFirewallManagementSubnet')
        }
        publicIPAddress: {
          id: resourceId('Microsoft.Network/publicIPAddresses', azureFirewallManagementPublicIpName)
        }
      }
    } : null
  }
  dependsOn: [
    vnet
    azureFirewallPublicIp
    azureFirewallManagementPublicIp
    azureFirewallPolicyRules
  ]
}

resource hubRouteTable 'Microsoft.Network/routeTables@2024-05-01' = if (deployAzureFirewall) {
  name: 'rt-${prefixedVnetName}-via-azfw'
  location: location
  properties: {
    disableBgpRoutePropagation: false
    routes: [for prefix in hubRoutePrefixes: {
      name: 'to-${replace(replace(prefix, '.', '-'), '/', '-')}'
      properties: {
        addressPrefix: prefix
        nextHopType: 'VirtualAppliance'
        nextHopIpAddress: azureFirewall!.properties.ipConfigurations[0].properties.privateIPAddress
      }
    }]
  }
}

resource spokeRouteTables 'Microsoft.Network/routeTables@2024-05-01' = [
  for (spoke, index) in spokeConfigs: if (deployAzureFirewall) {
    name: 'rt-${spoke.name}-vnet-via-azfw'
    location: location
    properties: {
      disableBgpRoutePropagation: true
      routes: [for prefix in union(filter(protectedNetworkPrefixes, prefix => prefix != spoke.vnetPrefix), [
        internetDefaultPrefix
      ]): {
        name: 'to-${replace(replace(prefix, '.', '-'), '/', '-')}'
        properties: {
          addressPrefix: prefix
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: azureFirewall!.properties.ipConfigurations[0].properties.privateIPAddress
        }
      }]
    }
  }
]

resource gatewayReturnRouteTable 'Microsoft.Network/routeTables@2024-05-01' = if (deployAzureFirewall && deployVpnGateway) {
  name: 'rt-${prefixedVnetName}-gateway-return-via-azfw'
  location: location
  properties: {
    disableBgpRoutePropagation: false
    routes: [for prefix in gatewayReturnPrefixes: {
      name: 'to-${replace(replace(prefix, '.', '-'), '/', '-')}'
      properties: {
        addressPrefix: prefix
        nextHopType: 'VirtualAppliance'
        nextHopIpAddress: azureFirewall!.properties.ipConfigurations[0].properties.privateIPAddress
      }
    }]
  }
}

resource fortiGateLocalNetworkGateway 'Microsoft.Network/localNetworkGateways@2023-11-01' = if (createFortiGateLocalNetworkGateway) {
  name: fortiGateLocalNetworkGatewayName
  location: location
  properties: {
    gatewayIpAddress: fortiGatePublicIp
    localNetworkAddressSpace: {
      addressPrefixes: onPremisesAddressPrefixes
    }
    bgpSettings: enableFortiGateBgp ? {
      asn: fortiGateBgpAsn
      bgpPeeringAddress: fortiGateBgpPeerIp
      peerWeight: 0
    } : null
  }
}

resource fortiGateConnection 'Microsoft.Network/connections@2023-11-01' = if (deployFortiGateConnection) {
  name: fortiGateConnectionName
  location: location
  properties: {
    connectionType: 'IPsec'
    connectionProtocol: 'IKEv2'
    virtualNetworkGateway1: {
      id: vpnGateway.id
      properties: {}
    }
    localNetworkGateway2: {
      id: fortiGateLocalNetworkGateway.id
      properties: {}
    }
    sharedKey: 'S2SPSK123!'
    enableBgp: enableFortiGateBgp
    routingWeight: 0
    dpdTimeoutSeconds: 45
  }
}

// --- VM NIC (static private IP, no public IP) ---------------
resource nic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: vmNicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: '${vnet.id}/subnets/${subnet1Name}'
          }
          privateIPAllocationMethod: 'Static'
          privateIPAddress: vmPrivateIp
        }
      }
    ]
  }
}

// --- Ubuntu 22.04 VM ----------------------------------------
resource vm 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
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
          id: nic.id
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

// --- Spoke VNets (10.21-10.23) with a /25 Subnet-1 ----------
resource spokeVnets 'Microsoft.Network/virtualNetworks@2023-11-01' = [
  for spoke in spokeConfigs: {
    name: '${spoke.name}-vnet'
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

resource hubWorkloadSubnetRouteAssociation 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = if (deployAzureFirewall) {
  parent: vnet
  name: subnet1Name
  properties: {
    addressPrefix: hubSubnetPrefix
    networkSecurityGroup: {
      id: nsg.id
    }
    routeTable: {
      id: hubRouteTable.id
    }
  }
}

resource spokeSubnetRouteAssociations 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = [
  for (spoke, index) in spokeConfigs: if (deployAzureFirewall) {
    parent: spokeVnets[index]
    name: 'Subnet-1'
    properties: {
      addressPrefix: spoke.subnetPrefix
      routeTable: {
        id: spokeRouteTables[index].id
      }
    }
  }
]

resource gatewaySubnetRouteAssociation 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = if (deployAzureFirewall && deployVpnGateway) {
  parent: vnet
  name: 'GatewaySubnet'
  properties: {
    addressPrefix: gatewaySubnetPrefix
    routeTable: {
      id: gatewayReturnRouteTable.id
    }
  }
}

// --- Hub-to-spoke peering (offers the hub VPN gateway) ------
resource hubToSpokePeerings 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-11-01' = [
  for (spoke, i) in spokeConfigs: {
    parent: vnet
    name: '${prefixedVnetName}-to-${spoke.name}-vnet'
    properties: {
      remoteVirtualNetwork: {
        id: spokeVnets[i].id
      }
      allowVirtualNetworkAccess: true
      allowForwardedTraffic: true
      allowGatewayTransit: deployVpnGateway
      useRemoteGateways: false
    }
  }
]

// --- Spoke-to-hub peering (routes via the hub VPN gateway) --
resource spokeToHubPeerings 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-11-01' = [
  for (spoke, i) in spokeConfigs: {
    parent: spokeVnets[i]
    name: '${spoke.name}-vnet-to-${prefixedVnetName}'
    properties: {
      remoteVirtualNetwork: {
        id: vnet.id
      }
      allowVirtualNetworkAccess: true
      allowForwardedTraffic: true
      allowGatewayTransit: false
      useRemoteGateways: deployVpnGateway
    }
    dependsOn: [
      vpnGateway
      hubToSpokePeerings
    ]
  }
]

// --- Spoke VM NICs ------------------------------------------
resource spokeNics 'Microsoft.Network/networkInterfaces@2023-11-01' = [
  for (spoke, i) in spokeConfigs: {
    name: '${spoke.name}-vm-nic'
    location: location
    properties: {
      ipConfigurations: [
        {
          name: 'ipconfig1'
          properties: {
            subnet: {
              id: '${spokeVnets[i].id}/subnets/Subnet-1'
            }
            privateIPAllocationMethod: 'Static'
            privateIPAddress: spoke.vmPrivateIp
          }
        }
      ]
    }
  }
]

// --- Spoke Ubuntu 22.04 VMs (smallest size) ----------------
resource spokeVms 'Microsoft.Compute/virtualMachines@2024-03-01' = [
  for (spoke, i) in spokeConfigs: {
    name: '${spoke.name}-vm'
    location: location
    properties: {
      hardwareProfile: {
        vmSize: spokeVmSize
      }
      osProfile: {
        computerName: '${spoke.name}-vm'
        adminUsername: adminUsername
        adminPassword: adminPassword
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
            id: spokeNics[i].id
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

// --- Outputs ------------------------------------------------
output networkSecurityGroupName string = nsg.name
output gatewayPublicIpName string = deployVpnGateway ? vpnGatewayPipName : ''
output vnetName string = vnet.name
output vnetId string = vnet.id
output vmName string = vm.name
output vmNicName string = nic.name
output vmPrivateIp string = nic.properties.ipConfigurations[0].properties.privateIPAddress
output vpnGatewaySku string = vpnGatewaySku
output vpnGatewayName string = deployVpnGateway ? vpnGateway.name : ''
output vpnGatewayId string = deployVpnGateway ? vpnGateway.id : ''
output azureFirewallSku string = azureFirewallSku
output azureFirewallName string = deployAzureFirewall ? azureFirewall.name : ''
output azureFirewallPolicyName string = deployAzureFirewall ? azureFirewallPolicy.name : ''
output azureFirewallPrivateIp string = deployAzureFirewall ? azureFirewall!.properties.ipConfigurations[0].properties.privateIPAddress : ''
output hubRouteTableId string = deployAzureFirewall ? hubRouteTable.id : ''
output spokeRouteTableIds array = deployAzureFirewall ? [
  resourceId('Microsoft.Network/routeTables', 'rt-${spokeConfigs[0].name}-vnet-via-azfw')
  resourceId('Microsoft.Network/routeTables', 'rt-${spokeConfigs[1].name}-vnet-via-azfw')
  resourceId('Microsoft.Network/routeTables', 'rt-${spokeConfigs[2].name}-vnet-via-azfw')
] : []
output gatewayReturnRouteTableId string = deployAzureFirewall && deployVpnGateway ? gatewayReturnRouteTable.id : ''
output spokeVnetNames array = [for (spoke, i) in spokeConfigs: spokeVnets[i].name]
output spokeVmNames array = [for (spoke, i) in spokeConfigs: spokeVms[i].name]
output spokeVmPrivateIps array = [for (spoke, i) in spokeConfigs: spokeNics[i].properties.ipConfigurations[0].properties.privateIPAddress]
