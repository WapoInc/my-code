// Writes the route table and attaches it to the subnet.
// Kept separate from the reader module because a template cannot read
// a resource as `existing` and redeploy it in the same scope.

targetScope = 'resourceGroup'

param routeTableName string
param location string
param tags object
param disableBgpRoutePropagation bool
param routes array
param vnetName string
param subnetName string

@description('Current subnet properties; merged so only routeTable changes.')
param subnetProperties object

resource routeTable 'Microsoft.Network/routeTables@2024-05-01' = {
  name: routeTableName
  location: location
  tags: tags
  properties: {
    disableBgpRoutePropagation: disableBgpRoutePropagation
    routes: routes
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: vnetName
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: vnet
  name: subnetName
  properties: union(subnetProperties, {
    routeTable: {
      id: routeTable.id
    }
  })
}

output routeTableId string = routeTable.id
