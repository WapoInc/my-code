// Reads the existing route table and subnet, then hands their current
// settings to the apply module so nothing outside the routes and the
// route-table association is changed (tags, BGP propagation, NSG,
// service endpoints, delegations, etc. are preserved).
//
// The route table must already exist; the deployment fails if it does not.

targetScope = 'resourceGroup'

param routeTableName string
param vnetName string
param subnetName string
param routes array

resource existingRouteTable 'Microsoft.Network/routeTables@2024-05-01' existing = {
  name: routeTableName
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: vnetName
}

resource existingSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = {
  parent: vnet
  name: subnetName
}

module apply 'route-table-association-apply.bicep' = {
  name: '${deployment().name}-apply'
  params: {
    routeTableName: routeTableName
    location: existingRouteTable.location
    tags: existingRouteTable.?tags ?? {}
    disableBgpRoutePropagation: existingRouteTable.properties.?disableBgpRoutePropagation ?? false
    routes: routes
    vnetName: vnetName
    subnetName: subnetName
    subnetProperties: existingSubnet.properties
  }
}

output routeTableId string = apply.outputs.routeTableId
