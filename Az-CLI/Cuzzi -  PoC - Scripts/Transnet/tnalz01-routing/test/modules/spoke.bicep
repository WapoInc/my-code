param location string
param tags object
param vnetName string
param subnetName string
param addressPrefix string
param routeTableName string
param routes array
param hubVnetId string

@description('Optional {name, routes} route table attached to the subnet instead of routeTableName (TCC-PRD temp_all_88_221).')
param legacyRouteTable object?

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-${subnetName}'
  location: location
  tags: tags
}

resource routeTable 'Microsoft.Network/routeTables@2024-05-01' = {
  name: routeTableName
  location: location
  tags: union(tags, {
    preserveCheck: 'this tag should survive remediation'
  })
  properties: {
    disableBgpRoutePropagation: false
    routes: routes
  }
}

resource legacy 'Microsoft.Network/routeTables@2024-05-01' = if (legacyRouteTable != null) {
  name: legacyRouteTable.?name ?? 'unused'
  location: location
  tags: tags
  properties: {
    routes: legacyRouteTable.?routes ?? []
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: addressPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
          routeTable: {
            id: legacyRouteTable != null ? legacy.id : routeTable.id
          }
        }
      }
    ]
  }
}

resource toHub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = {
  parent: vnet
  name: 'peer-to-hub'
  properties: {
    remoteVirtualNetwork: {
      id: hubVnetId
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
  }
}

output vnetId string = vnet.id
