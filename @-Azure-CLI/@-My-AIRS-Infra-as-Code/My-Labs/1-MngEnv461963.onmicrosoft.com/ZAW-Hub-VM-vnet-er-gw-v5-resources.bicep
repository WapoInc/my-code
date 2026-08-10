targetScope = 'resourceGroup'

@description('Azure region for all resources.')
param location string = 'southafricawest'

@description('Name of the virtual network.')
param vnetName string = 'SA-West-vnet'

@description('Address prefix of the virtual network.')
param vnetPrefix string = '10.30.0.0/16'

@description('Address prefix of GatewaySubnet.')
param gatewaySubnetPrefix string = '10.30.0.0/26'

@description('Address prefix of AzureFirewallSubnet.')
param firewallSubnetPrefix string = '10.30.0.64/26'

@description('Address prefix of AzureFirewallManagementSubnet.')
param firewallManagementSubnetPrefix string = '10.30.0.128/26'

@description('Address prefix of AzureBastionSubnet.')
param bastionSubnetPrefix string = '10.30.0.192/26'

@description('Name of the VM subnet.')
param subnetName string = 'Subnet-1'

@description('Address prefix of the VM subnet.')
param subnetPrefix string = '10.30.1.0/24'

@description('Address prefix of RouteServerSubnet.')
param routeServerSubnetPrefix string = '10.30.2.0/26'

@description('Address prefix of DnsResolverInboundSubnet.')
param dnsInboundSubnetPrefix string = '10.30.2.64/27'

@description('Address prefix of DnsResolverOutboundSubnet.')
param dnsOutboundSubnetPrefix string = '10.30.2.96/27'

@description('Address prefix of AppGatewaySubnet.')
param appGatewaySubnetPrefix string = '10.30.3.0/24'

@description('Name of the ExpressRoute virtual network gateway.')
param gatewayName string = 'ER-GateWay-SA-West-Standard'

@description('Name of the gateway public IP address.')
param gatewayPublicIpName string = 'ER-GateWay-SA-West-Standard-pip'

@allowed([
  'Standard'
  'HighPerformance'
  'UltraPerformance'
  'ErGw1AZ'
  'ErGw2AZ'
  'ErGw3AZ'
])
@description('SKU of the ExpressRoute virtual network gateway.')
param gatewaySku string = 'Standard'

@description('Create the connection to the existing ExpressRoute circuit.')
param deployExpressRouteConnection bool = true

@description('Name of the ExpressRoute connection.')
param connectionName string = 'ER-SA-West-Connection-to-SA-West-Region'

@description('Name of the existing ExpressRoute circuit.')
param circuitName string = 'ER-LTSA-SA-West'

@description('Resource group containing the existing ExpressRoute circuit.')
param circuitResourceGroupName string = 'ER-LTSA-rg'

@description('Subscription containing the existing ExpressRoute circuit.')
param circuitSubscriptionId string = subscription().subscriptionId

@description('Routing weight for the ExpressRoute connection.')
@minValue(0)
param routingWeight int = 0

@description('Name of the virtual machine.')
param vmName string = 'ZAW-vm-01'

@description('Name of the virtual machine network interface.')
param vmNicName string = 'ZAW-vm-01-nic'

@description('Size of the virtual machine.')
param vmSize string = 'Standard_B2s'

@description('Static private IP address of the virtual machine.')
param vmPrivateIp string = '10.30.1.5'

@description('Administrator username for the virtual machine.')
param adminUsername string = 'rootadmin'

@secure()
@description('Administrator password for the virtual machine.')
param adminPassword string

resource gatewayPublicIp 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: gatewayPublicIpName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

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
          addressPrefix: firewallManagementSubnetPrefix
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: bastionSubnetPrefix
        }
      }
      {
        name: subnetName
        properties: {
          addressPrefix: subnetPrefix
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
          addressPrefix: appGatewaySubnetPrefix
        }
      }
    ]
  }
}

resource gateway 'Microsoft.Network/virtualNetworkGateways@2023-11-01' = {
  name: gatewayName
  location: location
  properties: {
    gatewayType: 'ExpressRoute'
    sku: {
      name: gatewaySku
      tier: gatewaySku
    }
    ipConfigurations: [
      {
        name: 'gatewayIpConfiguration'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${vnet.id}/subnets/GatewaySubnet'
          }
          publicIPAddress: {
            id: gatewayPublicIp.id
          }
        }
      }
    ]
  }
}

resource circuit 'Microsoft.Network/expressRouteCircuits@2023-11-01' existing = {
  name: circuitName
  scope: resourceGroup(circuitSubscriptionId, circuitResourceGroupName)
}

resource expressRouteConnection 'Microsoft.Network/connections@2023-11-01' = if (deployExpressRouteConnection) {
  name: connectionName
  location: location
  properties: {
    connectionType: 'ExpressRoute'
    routingWeight: routingWeight
    // The connection API accepts an ID-only gateway reference.
    #disable-next-line BCP035
    virtualNetworkGateway1: {
      id: gateway.id
    }
    peer: {
      id: circuit.id
    }
  }
}

resource vmNic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: vmNicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: '${vnet.id}/subnets/${subnetName}'
          }
          privateIPAllocationMethod: 'Static'
          privateIPAddress: vmPrivateIp
        }
      }
    ]
  }
}

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
          id: vmNic.id
        }
      ]
    }
  }
}

output vnetId string = vnet.id
output vmPrivateIp string = vmNic.properties.ipConfigurations[0].properties.privateIPAddress
output expressRouteGatewayId string = gateway.id
output expressRouteConnectionId string = deployExpressRouteConnection ? expressRouteConnection.id : ''
