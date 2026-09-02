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

param vnetName string = 'southafricanorth-vnet'
param vnetPrefix string = '10.10.0.0/20'

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

param windowsVmName string = 'SA-North-JB1'
param windowsVmPrivateIp string = '10.10.1.4'
param windowsAdminUsername string = 'adminroot'
param ubuntuVmName string = 'SA-North-JB2'
param ubuntuVmPrivateIp string = '10.10.1.5'
param ubuntuAdminUsername string = 'rootadmin'
param vmSize string = 'Standard_B2s'

@secure()
param windowsAdminPassword string

@secure()
param ubuntuAdminPassword string

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
var privateEndpointSubnetPrefix = '10.10.4.0/24'

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
      {
        name: 'Priv-end-points'
        properties: {
          addressPrefix: privateEndpointSubnetPrefix
          privateEndpointNetworkPolicies: 'Disabled'
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

// Reference the circuit by resource ID so the deployment does not need read
// access in the circuit's subscription/tenant. Cross-subscription or
// cross-tenant connections are authorized with the authorization key.
var circuitId = resourceId(circuitSubscriptionId, circuitResourceGroup, 'Microsoft.Network/expressRouteCircuits', circuitName)

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
      id: circuitId
    }
    authorizationKey: empty(authorizationKey) ? null : authorizationKey
  }
}

resource windowsNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: '${windowsVmName}-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-RDP-Any'
        properties: {
          priority: 1000
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource ubuntuNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: '${ubuntuVmName}-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-SSH-Any'
        properties: {
          priority: 1000
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource windowsNic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: '${windowsVmName}-nic'
  location: location
  properties: {
    networkSecurityGroup: {
      id: windowsNsg.id
    }
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: windowsVmPrivateIp
          subnet: {
            id: '${vnet.id}/subnets/${subnet1Name}'
          }
        }
      }
    ]
  }
}

resource ubuntuNic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: '${ubuntuVmName}-nic'
  location: location
  properties: {
    networkSecurityGroup: {
      id: ubuntuNsg.id
    }
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: ubuntuVmPrivateIp
          subnet: {
            id: '${vnet.id}/subnets/${subnet1Name}'
          }
        }
      }
    ]
  }
}

resource windowsVm 'Microsoft.Compute/virtualMachines@2024-11-01' = {
  name: windowsVmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter-azure-edition'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
    }
    osProfile: {
      computerName: windowsVmName
      adminUsername: windowsAdminUsername
      adminPassword: windowsAdminPassword
      windowsConfiguration: {
        enableAutomaticUpdates: true
        provisionVMAgent: true
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: windowsNic.id
          properties: {
            primary: true
          }
        }
      ]
    }
  }
}

resource ubuntuVm 'Microsoft.Compute/virtualMachines@2024-11-01' = {
  name: ubuntuVmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
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
          storageAccountType: 'StandardSSD_LRS'
        }
      }
    }
    osProfile: {
      computerName: ubuntuVmName
      adminUsername: ubuntuAdminUsername
      adminPassword: ubuntuAdminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
        provisionVMAgent: true
      }
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: ubuntuNic.id
          properties: {
            primary: true
          }
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
output windowsVmName string = windowsVm.name
output windowsVmNicName string = windowsNic.name
output windowsVmPrivateIp string = windowsNic.properties.ipConfigurations[0].properties.privateIPAddress
output ubuntuVmName string = ubuntuVm.name
output ubuntuVmNicName string = ubuntuNic.name
output ubuntuVmPrivateIp string = ubuntuNic.properties.ipConfigurations[0].properties.privateIPAddress
output erGatewayName string = ergw.name
output erGatewayId string = ergw.id
output erConnectionName string = deployErConnection ? erConnection.name : ''
output erConnectionId string = deployErConnection ? erConnection.id : ''
