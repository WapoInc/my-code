// ============================================================
// SA-North-HUB resources - VNet + Subnets + ER GW + ER Connection + VM
// South Africa North  |  v5 - Bicep (resource-group scoped module)
// ============================================================
// Called by the subscription-scoped orchestrator
// (ZAN-Hub-VM-vnet-er-gw-v5-rg.bicep), which creates the
// resource group and invokes this module.
// vmr
// The ER connection references the gateway's id, so ARM automatically
// waits for the ExpressRoute gateway to finish provisioning before it
// creates the connection.
//
// NOTE: The ExpressRoute Gateway typically takes 20-45 minutes to provision.
// ============================================================

targetScope = 'resourceGroup'

// --- Parameters ---------------------------------------------
@description('Azure region for all resources.')
param location string = 'southafricanorth'

param vnetName string = '${location}-vnet'
param vnetPrefix string = '10.10.0.0/16'

param subnet1Name string = 'SubNet-1'
param nsgName string = '${location}-default-nsg'

param gwName string = 'ER-GateWay-${location}-Standard'
param gwPipName string = 'ER-GateWay-${location}-Standard-pip'

@allowed([
  'Standard'
  'HighPerformance'
  'UltraPerformance'
  'ErGw1AZ'
  'ErGw2AZ'
  'ErGw3AZ'
])
param gwSku string = 'Standard'

// --- ExpressRoute connection parameters ---------------------
@description('Create the ExpressRoute connection after the gateway is ready.')
param deployErConnection bool = true

@description('Name for the ExpressRoute connection.')
param connectionName string = 'ER-${location}-Connection'

@description('Name of the existing ExpressRoute circuit.')
param circuitName string = 'ER-LIT-ZAN'

@description('Resource group that contains the ExpressRoute circuit.')
param circuitResourceGroup string = 'ER-LTSA-rg'

@description('Subscription ID of the circuit (defaults to the current subscription).')
param circuitSubscriptionId string = subscription().subscriptionId

@description('Routing weight for the ExpressRoute connection.')
param routingWeight int = 0

@description('Authorization key - only needed for cross-subscription/tenant circuits.')
@secure()
param authorizationKey string = ''

param vmName string = '${location}-JB-1'
param vmNicName string = '${vmName}-nic'
param vmSize string = 'Standard_B2s'
param vmPrivateIp string = '10.10.1.5'
param adminUsername string = 'rootadmin'

@secure()
param adminPassword string

// --- Subnet address prefixes (recommended hub sizes) --------
var gatewaySubnetPrefix = '10.10.0.0/26'
var firewallSubnetPrefix = '10.10.0.64/26'
var firewallMgmtSubnetPrefix = '10.10.0.128/26'
var bastionSubnetPrefix = '10.10.0.192/26'
var subnet1Prefix = '10.10.1.0/24'
var routeServerSubnetPrefix = '10.10.2.0/26'
var dnsInboundSubnetPrefix = '10.10.2.64/27'
var dnsOutboundSubnetPrefix = '10.10.2.96/27'
var appGwSubnetPrefix = '10.10.3.0/24'

// --- Default NSG (Azure built-in rules only) ----------------
resource nsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: []
  }
}

// --- Public IP for the ExpressRoute Gateway -----------------
resource gwPip 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: gwPipName
  location: location
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
          addressPrefix: subnet1Prefix
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
      {
        name: 'RouteServerSubnet'
        properties: {
          addressPrefix: routeServerSubnetPrefix
        }
      }
      {
        name: 'DnsResolverInboundSubnet'
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
        name: 'DnsResolverOutboundSubnet'
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
        name: 'AppGatewaySubnet'
        properties: {
          addressPrefix: appGwSubnetPrefix
        }
      }
    ]
  }
}

// --- ExpressRoute Gateway -----------------------------------
resource ergw 'Microsoft.Network/virtualNetworkGateways@2023-11-01' = {
  name: gwName
  location: location
  properties: {
    gatewayType: 'ExpressRoute'
    sku: {
      name: gwSku
      tier: gwSku
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

// --- Existing ER circuit (may be in another RG / subscription) ---
resource circuit 'Microsoft.Network/expressRouteCircuits@2023-11-01' existing = {
  name: circuitName
  scope: resourceGroup(circuitSubscriptionId, circuitResourceGroup)
}

// --- ExpressRoute Connection --------------------------------
// Referencing ergw.id makes ARM wait for the gateway to finish first.
resource erConnection 'Microsoft.Network/connections@2023-11-01' = if (deployErConnection) {
  name: connectionName
  location: location
  // Explicitly wait for the ExpressRoute gateway to finish provisioning
  dependsOn: [
    #disable-next-line no-unnecessary-dependson
    ergw
  ]
  properties: {
    connectionType: 'ExpressRoute'
    routingWeight: routingWeight
    // Only the resource id is used for these references
    #disable-next-line BCP035
    virtualNetworkGateway1: {
      id: ergw.id
    }
    peer: {
      id: circuit.id
    }
    authorizationKey: empty(authorizationKey) ? null : authorizationKey
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
output gatewayPublicIpName string = gwPip.name
output vnetName string = vnet.name
output vnetId string = vnet.id
output vmName string = vm.name
output vmNicName string = nic.name
output vmPrivateIp string = nic.properties.ipConfigurations[0].properties.privateIPAddress
output erGatewayName string = ergw.name
output erGatewayId string = ergw.id
output erConnectionName string = deployErConnection ? erConnection.name : ''
output erConnectionId string = deployErConnection ? erConnection.id : ''
