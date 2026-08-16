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

param vnetName string = '${location}-vnet'
param vnetPrefix string = '10.20.0.0/16'

param subnet1Name string = 'ZA-East-Hub'
param nsgName string = '${location}-default-nsg'

@allowed([
  'None'
  'Basic'
  'VpnGw1AZ'
  'VpnGw2AZ'
  'VpnGw3AZ'
  'VpnGw4AZ'
  'VpnGw5AZ'
])
@description('VPN gateway SKU to deploy. Select None to skip the VPN gateway and its public IP.')
param vpnGatewaySku string = 'None'

param vpnGatewayName string = 'VPN-Gateway-${location}-${vpnGatewaySku}'
param vpnGatewayPipName string = '${vpnGatewayName}-zones123-pip'

var deployVpnGateway = vpnGatewaySku != 'None'

param vmName string = '${location}-JB-1'
param vmNicName string = '${vmName}-nic'
param vmSize string = 'Standard_B2s'
param vmPrivateIp string = '10.20.1.5'
param adminUsername string = 'rootadmin'

@secure()
param adminPassword string

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

// --- VNet with all hub subnets ------------------------------
resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: vnetName
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
  name: vpnGatewayName
  location: location
  properties: {
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    activeActive: false
    enableBgp: false
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
            id: gwPip.id
          }
        }
      }
    ]
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
  }
}

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
