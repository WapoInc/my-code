// Parameters
@description('Location for all resources')
param location string = 'southafricanorth'

@description('Resource group name')
param resourceGroupName string = 'poc1-demo-rg44'

@description('Admin username for VMs')
param adminUsername string = 'adminazure'

@description('Admin password for VMs')
@secure()
param adminPassword string

@description('Shared key for VPN connection')
@secure()
param sharedKey string = 'AzureSharedKey123'

// Variables - Network Configuration
var onpremVnetName = 'onprem-vnet'
var azureVnetName = 'azure-vnet'

var onpremVnetPrefix1 = '192.168.0.0/22'
var onpremVnetPrefix2 = '192.168.4.0/22'
var onpremSubnetPrefix = '192.168.1.0/24'
var onpremSubnet10Prefix = '192.168.4.0/24'
var onpremGatewaySubnetPrefix = '192.168.0.0/27'

var azureVnetPrefix = '10.70.0.0/22'
var azureSubnetPrefix = '10.70.1.0/24'
var azureGatewaySubnetPrefix = '10.70.0.0/27'
var azureFirewallSubnetPrefix = '10.70.3.0/26'

var onpremVm1Name = 'onprem-vm1'
var onpremVm2Name = 'onprem-vm2'
var azureVm1Name = 'azure-vm1'

var firewallName = 'azure-firewall'
var firewallPipName = 'azure-firewall-pip'

var vmSize = 'Standard_B2s'
var ubuntuImage = {
  publisher: 'Canonical'
  offer: '0001-com-ubuntu-server-jammy'
  sku: '22_04-lts-gen2'
  version: 'latest'
}

// On-premises Virtual Network
resource onpremVnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: onpremVnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        onpremVnetPrefix1
        onpremVnetPrefix2
      ]
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: onpremSubnetPrefix
        }
      }
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: onpremGatewaySubnetPrefix
        }
      }
      {
        name: 'Subnet-10'
        properties: {
          addressPrefix: onpremSubnet10Prefix
        }
      }
    ]
  }
}

// Azure Virtual Network
resource azureVnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: azureVnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        azureVnetPrefix
      ]
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: azureSubnetPrefix
        }
      }
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: azureGatewaySubnetPrefix
        }
      }
      {
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: azureFirewallSubnetPrefix
        }
      }
    ]
  }
}

// Public IPs for VPN Gateways
resource onpremGatewayPip 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: 'onprem-gateway-pip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource azureGatewayPip 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: 'azure-gateway-pip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// Public IP for Azure Firewall
resource firewallPip 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: firewallPipName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// On-premises VPN Gateway
resource onpremGateway 'Microsoft.Network/virtualNetworkGateways@2023-05-01' = {
  name: 'onprem-gateway'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'default'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${onpremVnet.id}/subnets/GatewaySubnet'
          }
          publicIPAddress: {
            id: onpremGatewayPip.id
          }
        }
      }
    ]
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    sku: {
      name: 'VpnGw1'
      tier: 'VpnGw1'
    }
  }
}

// Azure VPN Gateway
resource azureGateway 'Microsoft.Network/virtualNetworkGateways@2023-05-01' = {
  name: 'azure-gateway'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'default'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${azureVnet.id}/subnets/GatewaySubnet'
          }
          publicIPAddress: {
            id: azureGatewayPip.id
          }
        }
      }
    ]
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    sku: {
      name: 'VpnGw1'
      tier: 'VpnGw1'
    }
  }
}

// Azure Firewall
resource firewall 'Microsoft.Network/azureFirewalls@2023-05-01' = {
  name: firewallName
  location: location
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: 'Standard'
    }
    ipConfigurations: [
      {
        name: 'firewallConfig'
        properties: {
          subnet: {
            id: '${azureVnet.id}/subnets/AzureFirewallSubnet'
          }
          publicIPAddress: {
            id: firewallPip.id
          }
        }
      }
    ]
  }
}

// Local Network Gateways
resource azureLocalGateway 'Microsoft.Network/localNetworkGateways@2023-05-01' = {
  name: 'azure-local-gateway'
  location: location
  properties: {
    gatewayIpAddress: azureGatewayPip.properties.ipAddress
    localNetworkAddressSpace: {
      addressPrefixes: [
        azureVnetPrefix
      ]
    }
  }
  dependsOn: [
    azureGateway
  ]
}

resource onpremLocalGateway 'Microsoft.Network/localNetworkGateways@2023-05-01' = {
  name: 'onprem-local-gateway'
  location: location
  properties: {
    gatewayIpAddress: onpremGatewayPip.properties.ipAddress
    localNetworkAddressSpace: {
      addressPrefixes: [
        onpremVnetPrefix1
        onpremVnetPrefix2
      ]
    }
  }
  dependsOn: [
    onpremGateway
  ]
}

// VPN Connections
resource onpremToAzureConnection 'Microsoft.Network/connections@2023-05-01' = {
  name: 'onprem-to-azure'
  location: location
  properties: {
    virtualNetworkGateway1: {
      id: onpremGateway.id
      properties: {}
    }
    localNetworkGateway2: {
      id: azureLocalGateway.id
      properties: {}
    }
    connectionType: 'IPsec'
    sharedKey: sharedKey
  }
}

resource azureToOnpremConnection 'Microsoft.Network/connections@2023-05-01' = {
  name: 'azure-to-onprem'
  location: location
  properties: {
    virtualNetworkGateway1: {
      id: azureGateway.id
      properties: {}
    }
    localNetworkGateway2: {
      id: onpremLocalGateway.id
      properties: {}
    }
    connectionType: 'IPsec'
    sharedKey: sharedKey
  }
}

// Network Interfaces for VMs
resource onpremVm1Nic 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: '${onpremVm1Name}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${onpremVnet.id}/subnets/default'
          }
        }
      }
    ]
  }
}

resource onpremVm2Nic 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: '${onpremVm2Name}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${onpremVnet.id}/subnets/Subnet-10'
          }
        }
      }
    ]
  }
}

resource azureVm1Nic 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: '${azureVm1Name}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${azureVnet.id}/subnets/default'
          }
        }
      }
    ]
  }
}

// Virtual Machines
resource onpremVm1 'Microsoft.Compute/virtualMachines@2023-07-01' = {
  name: onpremVm1Name
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: onpremVm1Name
      adminUsername: adminUsername
      adminPassword: adminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    storageProfile: {
      imageReference: ubuntuImage
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
          id: onpremVm1Nic.id
        }
      ]
    }
  }
}

resource onpremVm2 'Microsoft.Compute/virtualMachines@2023-07-01' = {
  name: onpremVm2Name
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: onpremVm2Name
      adminUsername: adminUsername
      adminPassword: adminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    storageProfile: {
      imageReference: ubuntuImage
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
          id: onpremVm2Nic.id
        }
      ]
    }
  }
}

resource azureVm1 'Microsoft.Compute/virtualMachines@2023-07-01' = {
  name: azureVm1Name
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: azureVm1Name
      adminUsername: adminUsername
      adminPassword: adminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    storageProfile: {
      imageReference: ubuntuImage
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
          id: azureVm1Nic.id
        }
      ]
    }
  }
}

// Outputs
output onpremGatewayPublicIp string = onpremGatewayPip.properties.ipAddress
output azureGatewayPublicIp string = azureGatewayPip.properties.ipAddress
output firewallPublicIp string = firewallPip.properties.ipAddress
output onpremVm1PrivateIp string = onpremVm1Nic.properties.ipConfigurations[0].properties.privateIPAddress
output onpremVm2PrivateIp string = onpremVm2Nic.properties.ipConfigurations[0].properties.privateIPAddress
output azureVm1PrivateIp string = azureVm1Nic.properties.ipConfigurations[0].properties.privateIPAddress
