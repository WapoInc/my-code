targetScope = 'resourceGroup'

@description('Deployment stages permit a controlled routing rollout after the firewall is provisioned.')
@allowed([
  'FirewallOnly'
  'GatewayAndTestSpoke'
  'AllSpokes'
  'Full'
])
param deploymentStage string = 'FirewallOnly'

@description('Azure region containing the existing ZA-East networks.')
param location string = resourceGroup().location

@description('Name of the existing ZA-East hub virtual network.')
param hubVnetName string = 'za-east-southafricanorth-vnet'

@description('Name of the NSG already associated with the ZA-East-Hub workload subnet.')
param hubWorkloadNsgName string = 'za-east-southafricanorth-default-nsg'

@description('Approved on-premises CIDR prefixes learned through the VPN gateway. Do not include Azure prefixes or 0.0.0.0/0.')
param approvedOnPremisesPrefixes array = []

@description('Send Internet-bound traffic from protected workloads to Azure Firewall, where policy permits HTTP and HTTPS egress.')
param enableInternetEgressRouting bool = true

@description('Name of the Log Analytics workspace created for Azure Firewall diagnostics.')
param logAnalyticsWorkspaceName string = 'AzFW-Basic-LA'

@description('Deploy Azure Firewall across availability zones supported by the selected region. Use an empty array for a regional deployment.')
param firewallZones array = [
  '1'
  '2'
  '3'
]

param firewallName string = 'AzFW-ZA-East-vDC'
param firewallPolicyName string = 'AzFW-ZA-East-vDC-Policy-1'
param firewallPublicIpName string = 'AzFW-ZA-East-vDC-Pub-IP'
param firewallManagementPublicIpName string = 'AzFW-ZA-East-vDC-Mgmt-Pub-IP'
param firewallRuleCollectionGroupName string = 'AzFW-ZA-East-vDC-Policy-1-Private-RCG'

var spokeConfigs = [
  {
    name: 'za-east-spoke-1'
    vnetName: 'za-east-spoke-1-vnet'
    vnetPrefix: '10.21.0.0/24'
    subnetName: 'Subnet-1'
    subnetPrefix: '10.21.0.0/25'
    routeTableName: 'rt-za-east-spoke-1-via-azfw'
  }
  {
    name: 'za-east-spoke-2'
    vnetName: 'za-east-spoke-2-vnet'
    vnetPrefix: '10.22.0.0/24'
    subnetName: 'Subnet-1'
    subnetPrefix: '10.22.0.0/25'
    routeTableName: 'rt-za-east-spoke-2-via-azfw'
  }
  {
    name: 'za-east-spoke-3'
    vnetName: 'za-east-spoke-3-vnet'
    vnetPrefix: '10.23.0.0/24'
    subnetName: 'Subnet-1'
    subnetPrefix: '10.23.0.0/25'
    routeTableName: 'rt-za-east-spoke-3-via-azfw'
  }
]

var hubWorkloadSubnets = [
  {
    name: 'Subnet-1'
    prefix: '10.20.1.0/25'
    networkSecurityGroupName: hubWorkloadNsgName
  }
  {
    name: 'Ping-test'
    prefix: '10.20.8.0/24'
    networkSecurityGroupName: ''
  }
]

var spokeVnetPrefixes = [for spoke in spokeConfigs: spoke.vnetPrefix]
var hubWorkloadPrefixes = [for subnet in hubWorkloadSubnets: subnet.prefix]
var privateSitePrefixes = union(hubWorkloadPrefixes, spokeVnetPrefixes, approvedOnPremisesPrefixes)
var spokeRoutingConfigs = [
  for spoke in spokeConfigs: union(spoke, {
    routePrefixes: union(
      filter(privateSitePrefixes, prefix => prefix != spoke.vnetPrefix),
      enableInternetEgressRouting ? [
        '0.0.0.0/0'
      ] : []
    )
  })
]
var hubRoutePrefixes = union(
  spokeVnetPrefixes,
  approvedOnPremisesPrefixes,
  enableInternetEgressRouting ? [
    '0.0.0.0/0'
  ] : []
)
var deployGatewayRoutes = deploymentStage != 'FirewallOnly'
var deployAllSpokeRoutes = deploymentStage == 'AllSpokes' || deploymentStage == 'Full'
var deployHubRoutes = deploymentStage == 'Full'

resource hubVnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: hubVnetName
}

resource spokeVnets 'Microsoft.Network/virtualNetworks@2024-05-01' existing = [
  for spoke in spokeConfigs: {
    name: spoke.vnetName
  }
]

resource hubWorkloadNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' existing = {
  name: hubWorkloadNsgName
}

resource firewallPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: firewallPublicIpName
  location: location
  zones: firewallZones
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource firewallManagementPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: firewallManagementPublicIpName
  location: location
  zones: firewallZones
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource firewallPolicy 'Microsoft.Network/firewallPolicies@2024-05-01' = {
  name: firewallPolicyName
  location: location
  properties: {
    sku: {
      tier: 'Basic'
    }
    threatIntelMode: 'Alert'
  }
}

resource firewallPolicyRules 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2024-05-01' = {
  parent: firewallPolicy
  name: firewallRuleCollectionGroupName
  properties: {
    priority: 200
    ruleCollections: [
      {
        name: 'Allow-Private-InterSite'
        priority: 200
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        action: {
          type: 'Allow'
        }
        rules: [
          {
            name: 'Allow-Approved-Private-Prefixes'
            ruleType: 'NetworkRule'
            ipProtocols: [
              'Any'
            ]
            sourceAddresses: privateSitePrefixes
            destinationAddresses: privateSitePrefixes
            destinationPorts: [
              '*'
            ]
          }
        ]
      }
      {
        name: 'Allow-Internet-Web-Egress'
        priority: 300
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        action: {
          type: 'Allow'
        }
        rules: [
          {
            name: 'Allow-HTTP-HTTPS-To-Internet'
            ruleType: 'ApplicationRule'
            sourceAddresses: union(hubWorkloadPrefixes, spokeVnetPrefixes)
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

resource firewall 'Microsoft.Network/azureFirewalls@2024-05-01' = {
  name: firewallName
  location: location
  zones: firewallZones
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: 'Basic'
    }
    threatIntelMode: 'Alert'
    firewallPolicy: {
      id: firewallPolicy.id
    }
    ipConfigurations: [
      {
        name: '${firewallName}-ipconfig'
        properties: {
          subnet: {
            id: '${hubVnet.id}/subnets/AzureFirewallSubnet'
          }
          publicIPAddress: {
            id: firewallPublicIp.id
          }
        }
      }
    ]
    managementIpConfiguration: {
      name: '${firewallName}-management-ipconfig'
      properties: {
        subnet: {
          id: '${hubVnet.id}/subnets/AzureFirewallManagementSubnet'
        }
        publicIPAddress: {
          id: firewallManagementPublicIp.id
        }
      }
    }
  }
  dependsOn: [
    firewallPolicyRules
  ]
}

resource spokeRouteTables 'Microsoft.Network/routeTables@2024-05-01' = [
  for spoke in spokeRoutingConfigs: {
    name: spoke.routeTableName
    location: location
    properties: {
      disableBgpRoutePropagation: true
      routes: [for prefix in spoke.routePrefixes: {
          name: 'to-${replace(replace(prefix, '.', '-'), '/', '-')}'
          properties: {
            addressPrefix: prefix
            nextHopType: 'VirtualAppliance'
            nextHopIpAddress: firewall.properties.ipConfigurations[0].properties.privateIPAddress
          }
        }]
    }
  }
]

resource hubWorkloadRouteTable 'Microsoft.Network/routeTables@2024-05-01' = {
  name: 'rt-za-east-hub-workloads-via-azfw'
  location: location
  properties: {
    disableBgpRoutePropagation: false
    routes: [for prefix in hubRoutePrefixes: {
        name: 'to-${replace(replace(prefix, '.', '-'), '/', '-')}'
        properties: {
          addressPrefix: prefix
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: firewall.properties.ipConfigurations[0].properties.privateIPAddress
        }
      }]
  }
}

resource gatewayReturnRouteTable 'Microsoft.Network/routeTables@2024-05-01' = {
  name: 'rt-za-east-gateway-return-via-azfw'
  location: location
  properties: {
    disableBgpRoutePropagation: false
    routes: [for prefix in union(spokeVnetPrefixes, hubWorkloadPrefixes): {
      name: 'to-${replace(replace(prefix, '.', '-'), '/', '-')}'
      properties: {
        addressPrefix: prefix
        nextHopType: 'VirtualAppliance'
        nextHopIpAddress: firewall.properties.ipConfigurations[0].properties.privateIPAddress
      }
    }]
  }
}

resource gatewaySubnetAssociation 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = if (deployGatewayRoutes) {
  parent: hubVnet
  name: 'GatewaySubnet'
  properties: {
    addressPrefix: '10.20.0.0/24'
    routeTable: {
      id: gatewayReturnRouteTable.id
    }
  }
}

resource spokeSubnetAssociations 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = [
  for (spoke, index) in spokeConfigs: if (deployAllSpokeRoutes || (deploymentStage == 'GatewayAndTestSpoke' && index == 0)) {
    parent: spokeVnets[index]
    name: spoke.subnetName
    properties: {
      addressPrefix: spoke.subnetPrefix
      routeTable: {
        id: spokeRouteTables[index].id
      }
    }
  }
]

resource hubWorkloadSubnetAssociations 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = [
  for subnet in hubWorkloadSubnets: if (deployHubRoutes) {
    parent: hubVnet
    name: subnet.name
    properties: {
      addressPrefix: subnet.prefix
      networkSecurityGroup: empty(subnet.networkSecurityGroupName) ? null : {
        id: hubWorkloadNsg.id
      }
      routeTable: {
        id: hubWorkloadRouteTable.id
      }
    }
  }
]

resource firewallDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${firewallName}-diagnostics'
  scope: firewall
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        categoryGroup: 'allLogs'
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

output firewallName string = firewall.name
output firewallPolicyName string = firewallPolicy.name
output firewallPrivateIp string = firewall.properties.ipConfigurations[0].properties.privateIPAddress
output firewallPublicIp string = firewallPublicIp.properties.ipAddress
output firewallManagementPublicIp string = firewallManagementPublicIp.properties.ipAddress
output logAnalyticsWorkspaceName string = logAnalyticsWorkspace.name
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id
output spokeRouteTableIds array = [for (_, index) in spokeConfigs: spokeRouteTables[index].id]
output hubWorkloadRouteTableId string = hubWorkloadRouteTable.id
output gatewayReturnRouteTableId string = gatewayReturnRouteTable.id
output deploymentStage string = deploymentStage
