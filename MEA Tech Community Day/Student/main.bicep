targetScope = 'resourceGroup'

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Administrator username for the Linux virtual machines.')
param adminUsername string = 'adminazure'

@secure()
@description('Administrator password for the Linux virtual machines.')
param adminPassword string

@secure()
@description('Pre-shared key for the on-premises-to-Azure VPN connection.')
param onpremToAzureSharedKey string

@secure()
@description('Pre-shared key for the Azure-to-on-premises VPN connection.')
param azureToOnpremSharedKey string

@description('Optional resource tags.')
param tags object = {
  workload: 'MEA-Tech-Community-Day'
  environment: 'Student-Lab'
}

var bootDiagnosticsStorageName = 'bootdiag${uniqueString(subscription().id, resourceGroup().id)}'

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'law-mea-tech-student'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

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

resource onpremVnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: 'onprem-vnet'
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

resource onpremBastionSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: onpremVnet
  name: 'AzureBastionSubnet'
  properties: {
    addressPrefix: '192.168.3.0/26'
  }
  dependsOn: [
    onpremGatewaySubnet
  ]
}

resource onpremBastionPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: 'onprem-bastion-pip'
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

resource onpremBastionHost 'Microsoft.Network/bastionHosts@2024-05-01' = {
  name: 'onprem-bastion'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    enableShareableLink: true
    ipConfigurations: [
      {
        name: 'bastionIpConfig'
        properties: {
          subnet: {
            id: onpremBastionSubnet.id
          }
          publicIPAddress: {
            id: onpremBastionPublicIp.id
          }
        }
      }
    ]
  }
}

resource azureVnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: 'azure-vnet'
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

resource azureFirewallSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: azureVnet
  name: 'AzureFirewallSubnet'
  properties: {
    addressPrefix: '10.70.3.0/26'
  }
}

resource firewallPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: 'AzFW-Pub-IP'
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
  name: 'AzFW-Policy-01'
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
              '192.168.2.0/24'
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
              '192.168.5.0/24'
            ]
            destinationAddresses: [
              '10.70.1.0/24'
            ]
            destinationPorts: [
              '*'
            ]
          }
          {
            name: 'Allow-Azure-to-0-0-0-0'
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
              '0.0.0.0'
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
  name: 'AzFW'
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

resource firewallDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: firewall
  name: 'AzFW-diagnostics'
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        category: 'AZFWNetworkRule'
        enabled: true
      }
      {
        category: 'AZFWApplicationRule'
        enabled: true
      }
      {
        category: 'AZFWNatRule'
        enabled: true
      }
      {
        category: 'AZFWThreatIntel'
        enabled: true
      }
      {
        category: 'AZFWIdpsSignature'
        enabled: true
      }
      {
        category: 'AZFWDnsQuery'
        enabled: true
      }
      {
        category: 'AZFWFqdnResolveFailure'
        enabled: true
      }
      {
        category: 'AZFWFatFlow'
        enabled: true
      }
      {
        category: 'AZFWFlowTrace'
        enabled: true
      }
      {
        category: 'AZFWApplicationRuleAggregation'
        enabled: true
      }
      {
        category: 'AZFWNetworkRuleAggregation'
        enabled: true
      }
      {
        category: 'AZFWNatRuleAggregation'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

resource azureHubRouteTable 'Microsoft.Network/routeTables@2024-05-01' = {
  name: 'azure-subnet-rt'
  location: location
  tags: tags
  properties: {
    disableBgpRoutePropagation: true
    routes: [
      {
        name: 'route-to-onprem-192-168-1-0'
        properties: {
          addressPrefix: '192.168.2.0/24'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: firewall.properties.ipConfigurations[0].properties.privateIPAddress
        }
      }
      {
        name: 'route-to-onprem-192-168-4-0'
        properties: {
          addressPrefix: '192.168.5.0/24'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: firewall.properties.ipConfigurations[0].properties.privateIPAddress
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
    disableBgpRoutePropagation: true
    routes: [
      {
        name: 'route-to-hub-subnet'
        properties: {
          addressPrefix: '10.70.2.0/24'
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

resource onpremGatewayPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: 'onprem-gateway-pip'
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
  name: 'azure-gateway-pip'
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
  name: 'onprem-vpn-gw'
  location: location
  tags: tags
  properties: {
    activeActive: false
    enableBgp: false
    gatewayType: 'Vpn'
    sku: {
      name: 'VpnGw1AZ'
      tier: 'VpnGw1AZ'
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
  name: 'azure-vpn-gw'
  location: location
  tags: tags
  properties: {
    activeActive: false
    enableBgp: false
    gatewayType: 'Vpn'
    sku: {
      name: 'VpnGw1AZ'
      tier: 'VpnGw1AZ'
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
    ]
  }
}

resource azureLocalGateway 'Microsoft.Network/localNetworkGateways@2024-05-01' = {
  name: 'azure-lng-gw'
  location: location
  tags: tags
  properties: {
    gatewayIpAddress: azureGatewayPublicIp.properties.ipAddress
    localNetworkAddressSpace: {
      addressPrefixes: [
        '10.70.0.0/22'
      ]
    }
  }
  dependsOn: [
    onpremGateway
    azureGateway
  ]
}

resource onpremLocalGateway 'Microsoft.Network/localNetworkGateways@2024-05-01' = {
  name: 'onprem-lng-gw'
  location: location
  tags: tags
  properties: {
    gatewayIpAddress: onpremGatewayPublicIp.properties.ipAddress
    localNetworkAddressSpace: {
      addressPrefixes: [
        '192.168.8.0/22'
      ]
    }
  }
  dependsOn: [
    onpremGateway
    azureGateway
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
    sharedKey: onpremToAzureSharedKey
    virtualNetworkGateway1: {
      id: onpremGateway.id
      properties: {}
    }
  }
  dependsOn: [
    onpremLocalGateway
  ]
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
    sharedKey: azureToOnpremSharedKey
    virtualNetworkGateway1: {
      id: azureGateway.id
      properties: {}
    }
  }
  dependsOn: [
    azureLocalGateway
  ]
}

resource onpremVm1Nic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: 'onprem-vm1-nic'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
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

output bootDiagnosticsStorageAccountName string = bootDiagnosticsStorage.name
output firewallPrivateIpAddress string = firewall.properties.ipConfigurations[0].properties.privateIPAddress
output firewallPublicIpAddress string = firewallPublicIp.properties.ipAddress
output logAnalyticsWorkspaceName string = logAnalyticsWorkspace.name
output onpremGatewayPublicIpAddress string = onpremGatewayPublicIp.properties.ipAddress
output azureGatewayPublicIpAddress string = azureGatewayPublicIp.properties.ipAddress
output onpremBastionHostName string = onpremBastionHost.name
