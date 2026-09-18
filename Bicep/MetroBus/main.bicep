targetScope = 'resourceGroup'

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Administrator username for the Linux virtual machines.')
param adminUsername string = 'adminazure'

@secure()
@description('Administrator password for the Linux virtual machines.')
param adminPassword string

@description('Smallest Azure VPN Gateway SKU that supports availability zones.')
@allowed([
  'VpnGw1AZ'
])
param vpnGatewaySku string = 'VpnGw1AZ'

@description('Name of the Log Analytics workspace that receives Azure Firewall logs.')
param logAnalyticsWorkspaceName string = 'law-mea-tech-community-day'

@description('Log Analytics retention period in days.')
@minValue(30)
param logAnalyticsRetentionInDays int = 30

@description('Optional resource tags.')
param tags object = {
  workload: 'MEA-Tech-Community-Day'
  environment: 'Lab'
}

var onpremVnetName = 'onprem-vnet'
var azureVnetName = 'azure-vnet'
var avsVnetName = 'avs-vnet'
var firewallName = 'AzFW'
var firewallPolicyName = 'AzFW-Policy-01'
var firewallPublicIpName = 'AzFW-Pub-IP'
var bootDiagnosticsStorageName = 'bootdiag${uniqueString(subscription().id, resourceGroup().id)}'
var hubVmPrivateIp = '10.70.2.68'
var hubVmBgpAsn = 65001
var vpnSharedKey = 'S2SPSK123!'

resource bootDiagnosticsStorage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: bootDiagnosticsStorageName
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  tags: tags
  properties: {
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    retentionInDays: logAnalyticsRetentionInDays
    sku: {
      name: 'PerGB2018'
    }
  }
}

resource onpremVnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: onpremVnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        '192.168.0.0/22'
        '192.168.4.0/22'
      ]
    }
  }
}

resource onpremHubSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: onpremVnet
  name: 'onprem-hub'
  properties: {
    addressPrefix: '192.168.1.0/24'
  }
}

resource onpremSubnet4 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: onpremVnet
  name: 'Subnet-4'
  properties: {
    addressPrefix: '192.168.4.0/24'
  }
  dependsOn: [
    onpremHubSubnet
  ]
}

resource onpremGatewaySubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: onpremVnet
  name: 'GatewaySubnet'
  properties: {
    addressPrefix: '192.168.0.0/27'
  }
  dependsOn: [
    onpremSubnet4
  ]
}

resource azureVnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: azureVnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.70.0.0/22'
      ]
    }
  }
}

resource avsVnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: avsVnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        '172.16.1.0/24'
      ]
    }
  }
}

resource azureFirewallSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: azureVnet
  name: 'AzureFirewallSubnet'
  properties: {
    addressPrefix: '10.70.3.0/26'
  }
}

resource firewallPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: firewallPublicIpName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

resource routeServerPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: 'azure-route-server-pip'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

resource firewallPolicy 'Microsoft.Network/firewallPolicies@2024-05-01' = {
  name: firewallPolicyName
  location: location
  tags: tags
  properties: {
    sku: {
      tier: 'Standard'
    }
    threatIntelMode: 'Alert'
  }
}

resource firewallRuleCollectionGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2024-05-01' = {
  parent: firewallPolicy
  name: 'DefaultNetworkRuleCollectionGroup'
  properties: {
    priority: 200
    ruleCollections: [
      {
        name: 'NetworkRuleCollection'
        priority: 100
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        action: {
          type: 'Allow'
        }
        rules: [
          {
            name: 'Allow-Onprem-Hub-to-Azure'
            ruleType: 'NetworkRule'
            ipProtocols: [
              'TCP'
              'UDP'
              'ICMP'
            ]
            sourceAddresses: [
              '192.168.1.0/24'
            ]
            destinationAddresses: [
              '10.70.1.0/24'
            ]
            destinationPorts: [
              '*'
            ]
          }
          {
            name: 'Allow-Onprem-Subnet4-to-Azure'
            ruleType: 'NetworkRule'
            ipProtocols: [
              'TCP'
              'UDP'
              'ICMP'
            ]
            sourceAddresses: [
              '192.168.4.0/24'
            ]
            destinationAddresses: [
              '10.70.1.0/24'
            ]
            destinationPorts: [
              '*'
            ]
          }
          {
            name: 'Allow-Azure-to-Onprem'
            ruleType: 'NetworkRule'
            ipProtocols: [
              'TCP'
              'UDP'
              'ICMP'
            ]
            sourceAddresses: [
              '10.70.1.0/24'
            ]
            destinationAddresses: [
              '192.168.1.0/24'
              '192.168.4.0/24'
            ]
            destinationPorts: [
              '*'
            ]
          }
          {
            name: 'Allow-Hub-VM-Package-Repositories'
            ruleType: 'NetworkRule'
            ipProtocols: [
              'TCP'
            ]
            sourceAddresses: [
              '10.70.2.64/29'
            ]
            destinationAddresses: [
              '*'
            ]
            destinationPorts: [
              '80'
              '443'
            ]
          }
          {
            name: 'onprem-to-avs-vnet'
            ruleType: 'NetworkRule'
            ipProtocols: [
              'Any'
            ]
            sourceAddresses: [
              '192.168.1.0/24'
            ]
            destinationAddresses: [
              '172.16.1.0/24'
            ]
            destinationPorts: [
              '*'
            ]
          }
        ]
      }
    ]
  }
}

resource firewall 'Microsoft.Network/azureFirewalls@2024-05-01' = {
  name: firewallName
  location: location
  tags: tags
  properties: {
    firewallPolicy: {
      id: firewallPolicy.id
    }
    ipConfigurations: [
      {
        name: 'azureFirewallIpConfiguration'
        properties: {
          subnet: {
            id: azureFirewallSubnet.id
          }
          publicIPAddress: {
            id: firewallPublicIp.id
          }
        }
      }
    ]
    sku: {
      name: 'AZFW_VNet'
      tier: 'Standard'
    }
    threatIntelMode: 'Alert'
  }
}

resource firewallDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'send-network-rule-logs-to-log-analytics'
  scope: firewall
  properties: {
    logAnalyticsDestinationType: 'Dedicated'
    logs: [
      {
        category: 'AzureFirewallNetworkRule'
        enabled: true
      }
    ]
    workspaceId: logAnalyticsWorkspace.id
  }
}

resource azureHubRouteTable 'Microsoft.Network/routeTables@2024-05-01' = {
  name: 'azure-subnet-rt'
  location: location
  tags: tags
  properties: {
    disableBgpRoutePropagation: false
    routes: [
      {
        name: 'route-to-onprem-192-168-1-0'
        properties: {
          addressPrefix: '192.168.1.0/24'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: firewall.properties.ipConfigurations[0].properties.privateIPAddress
        }
      }
      {
        name: 'route-to-onprem-192-168-4-0'
        properties: {
          addressPrefix: '192.168.4.0/24'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: firewall.properties.ipConfigurations[0].properties.privateIPAddress
        }
      }
      {
        name: 'to-avs-vnet'
        properties: {
          addressPrefix: '172.16.1.0/24'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: '10.70.3.4'
        }
      }
    ]
  }
}

resource azureGatewayRouteTable 'Microsoft.Network/routeTables@2024-05-01' = {
  name: 'azure-gateway-subnet-rt'
  location: location
  tags: tags
  properties: {
    disableBgpRoutePropagation: false
    routes: [
      {
        name: 'route-to-hub-subnet'
        properties: {
          addressPrefix: '10.70.1.0/24'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: firewall.properties.ipConfigurations[0].properties.privateIPAddress
        }
      }
      {
        name: 'route-to-avs'
        properties: {
          addressPrefix: '172.16.1.0/24'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: '10.70.3.4'
        }
      }
    ]
  }
}

resource hubVmRouteTable 'Microsoft.Network/routeTables@2024-05-01' = {
  name: 'hub-vm-subnet-rt'
  location: location
  tags: tags
  properties: {
    disableBgpRoutePropagation: false
    routes: [
      {
        name: 'default-via-azure-firewall'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: firewall.properties.ipConfigurations[0].properties.privateIPAddress
        }
      }
    ]
  }
}

resource azureHubSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: azureVnet
  name: 'azure-hub'
  properties: {
    addressPrefix: '10.70.1.0/24'
    routeTable: {
      id: azureHubRouteTable.id
    }
  }
}

resource azureGatewaySubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: azureVnet
  name: 'GatewaySubnet'
  properties: {
    addressPrefix: '10.70.0.0/27'
    routeTable: {
      id: azureGatewayRouteTable.id
    }
  }
  dependsOn: [
    azureHubSubnet
  ]
}

resource avsSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: avsVnet
  name: 'AVS0subnet'
  properties: {
    addressPrefix: '172.16.1.0/25'
  }
}

resource routeServerSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: azureVnet
  name: 'RouteServerSubnet'
  properties: {
    addressPrefix: '10.70.2.0/26'
  }
  dependsOn: [
    azureGatewaySubnet
  ]
}

resource hubVmSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: azureVnet
  name: 'hub-vm-subnet'
  properties: {
    addressPrefix: '10.70.2.64/29'
    routeTable: {
      id: hubVmRouteTable.id
    }
  }
  dependsOn: [
    routeServerSubnet
  ]
}

resource routeServer 'Microsoft.Network/virtualHubs@2024-05-01' = {
  name: 'azure-route-server'
  location: location
  tags: tags
  properties: {
    sku: 'Standard'
  }
  dependsOn: [
    azureGateway
  ]
}

resource routeServerIpConfig 'Microsoft.Network/virtualHubs/ipConfigurations@2024-05-01' = {
  parent: routeServer
  name: 'ipconfig1'
  properties: {
    subnet: {
      id: routeServerSubnet.id
    }
    publicIPAddress: {
      id: routeServerPublicIp.id
    }
  }
}

resource onpremGatewayPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: 'onprem-gateway-pip-zr'
  location: location
  zones: [
    '1'
    '2'
    '3'
  ]
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

resource azureGatewayPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: 'azure-gateway-pip-zr'
  location: location
  zones: [
    '1'
    '2'
    '3'
  ]
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

resource azureGatewayPublicIp2 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: 'azure-gateway-pip-zr-2'
  location: location
  zones: [
    '1'
    '2'
    '3'
  ]
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

resource onpremGateway 'Microsoft.Network/virtualNetworkGateways@2024-05-01' = {
  name: 'onprem-gateway'
  location: location
  tags: tags
  properties: {
    activeActive: false
    enableBgp: false
    gatewayType: 'Vpn'
    sku: {
      name: vpnGatewaySku
      tier: vpnGatewaySku
    }
    vpnGatewayGeneration: 'Generation1'
    vpnType: 'RouteBased'
    ipConfigurations: [
      {
        name: 'gwipconfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: onpremGatewayPublicIp.id
          }
          subnet: {
            id: onpremGatewaySubnet.id
          }
        }
      }
    ]
  }
}

resource azureGateway 'Microsoft.Network/virtualNetworkGateways@2024-05-01' = {
  name: 'azure-gateway'
  location: location
  tags: tags
  properties: {
    activeActive: true
    bgpSettings: {
      asn: 65515
    }
    enableBgp: false
    gatewayType: 'Vpn'
    sku: {
      name: vpnGatewaySku
      tier: vpnGatewaySku
    }
    vpnGatewayGeneration: 'Generation1'
    vpnType: 'RouteBased'
    ipConfigurations: [
      {
        name: 'gwipconfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: azureGatewayPublicIp.id
          }
          subnet: {
            id: azureGatewaySubnet.id
          }
        }
      }
      {
        name: 'gwipconfig2'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: azureGatewayPublicIp2.id
          }
          subnet: {
            id: azureGatewaySubnet.id
          }
        }
      }
    ]
  }
}

resource azureToAvsPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = {
  parent: azureVnet
  name: 'azure-to-avs'
  properties: {
    allowForwardedTraffic: true
    allowGatewayTransit: true
    allowVirtualNetworkAccess: true
    remoteVirtualNetwork: {
      id: avsVnet.id
    }
    useRemoteGateways: false
  }
  dependsOn: [
    azureGateway
  ]
}

resource avsToAzurePeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = {
  parent: avsVnet
  name: 'avs-to-azure'
  properties: {
    allowForwardedTraffic: true
    allowGatewayTransit: false
    allowVirtualNetworkAccess: true
    remoteVirtualNetwork: {
      id: azureVnet.id
    }
    useRemoteGateways: true
  }
  dependsOn: [
    azureToAvsPeering
  ]
}

resource azureLocalGateway 'Microsoft.Network/localNetworkGateways@2024-05-01' = {
  name: 'azure-local-gateway'
  location: location
  tags: tags
  properties: {
    gatewayIpAddress: azureGatewayPublicIp.properties.ipAddress
    localNetworkAddressSpace: {
      addressPrefixes: [
        '10.70.0.0/22'
        '172.16.1.0/24'
      ]
    }
  }
  dependsOn: [
    azureGateway
  ]
}

resource onpremLocalGateway 'Microsoft.Network/localNetworkGateways@2024-05-01' = {
  name: 'onprem-local-gateway'
  location: location
  tags: tags
  properties: {
    gatewayIpAddress: onpremGatewayPublicIp.properties.ipAddress
    localNetworkAddressSpace: {
      addressPrefixes: [
        '192.168.0.0/22'
        '192.168.4.0/22'
      ]
    }
  }
  dependsOn: [
    onpremGateway
  ]
}

resource onpremToAzureConnection 'Microsoft.Network/connections@2024-05-01' = {
  name: 'onprem-to-azure'
  location: location
  tags: tags
  properties: {
    connectionType: 'IPsec'
    localNetworkGateway2: {
      id: azureLocalGateway.id
      properties: {}
    }
    sharedKey: vpnSharedKey
    virtualNetworkGateway1: {
      id: onpremGateway.id
      properties: {}
    }
  }
}

resource azureToOnpremConnection 'Microsoft.Network/connections@2024-05-01' = {
  name: 'azure-to-onprem'
  location: location
  tags: tags
  properties: {
    connectionType: 'IPsec'
    localNetworkGateway2: {
      id: onpremLocalGateway.id
      properties: {}
    }
    sharedKey: vpnSharedKey
    virtualNetworkGateway1: {
      id: azureGateway.id
      properties: {}
    }
  }
}

resource onpremVm1PublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: 'onprem-vm1-pip'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

resource onpremVm1Nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'onprem-vm1-nsg'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-SSH'
        properties: {
          access: 'Allow'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
          direction: 'Inbound'
          priority: 1000
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
        }
      }
    ]
  }
}

resource onpremVm1Nic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: 'onprem-vm1-nic'
  location: location
  tags: tags
  properties: {
    networkSecurityGroup: {
      id: onpremVm1Nsg.id
    }
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: onpremVm1PublicIp.id
          }
          subnet: {
            id: onpremHubSubnet.id
          }
        }
      }
    ]
  }
}

resource onpremVm2Nic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: 'onprem-vm2-nic'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: onpremSubnet4.id
          }
        }
      }
    ]
  }
}

resource azureVm1Nic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: 'azure-vm1-nic'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: azureHubSubnet.id
          }
        }
      }
    ]
  }
}

resource avsVmNic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: 'avs-vm-nic'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: avsSubnet.id
          }
        }
      }
    ]
  }
}

resource hubVmNic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: 'hub-vm-nic'
  location: location
  tags: tags
  properties: {
    enableIPForwarding: true
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAddress: hubVmPrivateIp
          privateIPAllocationMethod: 'Static'
          subnet: {
            id: hubVmSubnet.id
          }
        }
      }
    ]
  }
}

resource onpremVm1 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: 'onprem-vm1'
  location: location
  tags: tags
  properties: {
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: bootDiagnosticsStorage.properties.primaryEndpoints.blob
      }
    }
    hardwareProfile: {
      vmSize: 'Standard_B2s'
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: onpremVm1Nic.id
          properties: {
            primary: true
          }
        }
      ]
    }
    osProfile: {
      adminPassword: adminPassword
      adminUsername: adminUsername
      computerName: 'onprem-vm1'
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    storageProfile: {
      imageReference: {
        offer: '0001-com-ubuntu-server-jammy'
        publisher: 'Canonical'
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
  }
}

resource onpremVm2 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: 'onprem-vm2'
  location: location
  tags: tags
  properties: {
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: bootDiagnosticsStorage.properties.primaryEndpoints.blob
      }
    }
    hardwareProfile: {
      vmSize: 'Standard_B2s'
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: onpremVm2Nic.id
          properties: {
            primary: true
          }
        }
      ]
    }
    osProfile: {
      adminPassword: adminPassword
      adminUsername: adminUsername
      computerName: 'onprem-vm2'
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    storageProfile: {
      imageReference: {
        offer: '0001-com-ubuntu-server-jammy'
        publisher: 'Canonical'
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
  }
}

resource azureVm1 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: 'azure-vm1'
  location: location
  tags: tags
  properties: {
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: bootDiagnosticsStorage.properties.primaryEndpoints.blob
      }
    }
    hardwareProfile: {
      vmSize: 'Standard_B2s'
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: azureVm1Nic.id
          properties: {
            primary: true
          }
        }
      ]
    }
    osProfile: {
      adminPassword: adminPassword
      adminUsername: adminUsername
      computerName: 'azure-vm1'
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    storageProfile: {
      imageReference: {
        offer: '0001-com-ubuntu-server-jammy'
        publisher: 'Canonical'
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
  }
}

resource avsVm 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: 'avs-vm'
  location: location
  tags: tags
  properties: {
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: bootDiagnosticsStorage.properties.primaryEndpoints.blob
      }
    }
    hardwareProfile: {
      vmSize: 'Standard_B2s'
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: avsVmNic.id
          properties: {
            primary: true
          }
        }
      ]
    }
    osProfile: {
      adminPassword: adminPassword
      adminUsername: adminUsername
      computerName: 'avs-vm'
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    storageProfile: {
      imageReference: {
        offer: '0001-com-ubuntu-server-jammy'
        publisher: 'Canonical'
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
  }
}

resource hubVm 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: 'hub-vm'
  location: location
  tags: tags
  properties: {
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: bootDiagnosticsStorage.properties.primaryEndpoints.blob
      }
    }
    hardwareProfile: {
      vmSize: 'Standard_B2s'
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: hubVmNic.id
          properties: {
            primary: true
          }
        }
      ]
    }
    osProfile: {
      adminPassword: adminPassword
      adminUsername: adminUsername
      computerName: 'hub-vm'
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    storageProfile: {
      imageReference: {
        offer: '0001-com-ubuntu-server-jammy'
        publisher: 'Canonical'
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
  }
}

var hubVmBgpConfigScript = '''
#!/bin/bash
set -euo pipefail

cat > /etc/sysctl.d/99-hub-vm-routing.conf <<'EOF'
net.ipv4.ip_forward=1
net.ipv4.conf.all.forwarding=1
net.ipv4.conf.all.rp_filter=0
net.ipv4.conf.default.rp_filter=0
EOF
sysctl --system

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -o DPkg::Lock::Timeout=600 install -y frr
sed -i 's/^bgpd=no/bgpd=yes/' /etc/frr/daemons

cat > /etc/frr/frr.conf <<'EOF'
frr defaults traditional
hostname hub-vm
service integrated-vtysh-config
!
router bgp ${hubVmBgpAsn}
 bgp router-id ${hubVmPrivateIp}
 no bgp ebgp-requires-policy
 neighbor ${routeServer.properties.virtualRouterIps[0]} remote-as 65515
 neighbor ${routeServer.properties.virtualRouterIps[0]} ebgp-multihop 2
 neighbor ${routeServer.properties.virtualRouterIps[1]} remote-as 65515
 neighbor ${routeServer.properties.virtualRouterIps[1]} ebgp-multihop 2
 !
 address-family ipv4 unicast
  neighbor ${routeServer.properties.virtualRouterIps[0]} activate
  neighbor ${routeServer.properties.virtualRouterIps[1]} activate
 exit-address-family
!
EOF

chown frr:frr /etc/frr/frr.conf
chmod 640 /etc/frr/frr.conf
systemctl enable --now frr
systemctl restart frr
'''

resource hubVmBgpExtension 'Microsoft.Compute/virtualMachines/extensions@2024-03-01' = {
  parent: hubVm
  name: 'configure-routing-and-frr'
  location: location
  tags: tags
  properties: {
    autoUpgradeMinorVersion: true
    forceUpdateTag: uniqueString(hubVmBgpConfigScript)
    publisher: 'Microsoft.Azure.Extensions'
    settings: {
      commandToExecute: 'echo ${base64(hubVmBgpConfigScript)} | base64 --decode | bash'
    }
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
  }
  dependsOn: [
    routeServerIpConfig
  ]
}

resource routeServerHubVmPeer 'Microsoft.Network/virtualHubs/bgpConnections@2024-05-01' = {
  parent: routeServer
  name: 'hub-vm'
  properties: {
    peerAsn: hubVmBgpAsn
    peerIp: hubVmPrivateIp
  }
  dependsOn: [
    hubVmBgpExtension
    routeServerIpConfig
  ]
}

output bootDiagnosticsStorageAccountName string = bootDiagnosticsStorage.name
output logAnalyticsWorkspaceName string = logAnalyticsWorkspace.name
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id
output firewallDiagnosticSettingName string = firewallDiagnostics.name
output networkRuleTableName string = 'AZFWNetworkRule'
output networkRuleSampleQuery string = 'AZFWNetworkRule | where TimeGenerated > ago(1h) | order by TimeGenerated desc'
output firewallPrivateIpAddress string = firewall.properties.ipConfigurations[0].properties.privateIPAddress
output firewallPublicIpAddress string = firewallPublicIp.properties.ipAddress
output onpremGatewayPublicIpAddress string = onpremGatewayPublicIp.properties.ipAddress
output azureGatewayPublicIpAddress string = azureGatewayPublicIp.properties.ipAddress
output azureGatewayPublicIpAddress2 string = azureGatewayPublicIp2.properties.ipAddress
output vpnGatewaySkuName string = vpnGatewaySku
output routeServerName string = routeServer.name
output routeServerPublicIpAddress string = routeServerPublicIp.properties.ipAddress
output onpremVm1PublicIpAddress string = onpremVm1PublicIp.properties.ipAddress
output hubVmPrivateIpAddress string = hubVmPrivateIp
output hubVmBgpAsn int = hubVmBgpAsn
output routeServerPeerIps array = routeServer.properties.virtualRouterIps
