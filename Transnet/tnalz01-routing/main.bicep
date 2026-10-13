// =====================================================================
// TNALZ01 SAP / Identity Route Table Remediation
//
// Purpose:
//   - SAP route tables: route Identity (10.116.4.0/24) via Azure Firewall.
//     No 0.0.0.0/0 route.
//   - Identity route table: route each SAP /24 via Azure Firewall.
//     No 0.0.0.0/0 route and no Identity self-route.
//   - TCC PRD exception: 88.221.0.0/16 -> Internet.
//   - Associate each route table with the correct subnet.
//
// IMPORTANT - declarative behaviour:
//   Each route table ends up with EXACTLY the routes declared here.
//   Any other route currently on these tables is removed.
//
// Network definitions live in networks.json (shared with test/).
//
// Dry run:
//   az deployment sub what-if --location southafricanorth --template-file main.bicep
// =====================================================================

targetScope = 'subscription'

@description('Azure Firewall private IP used as next hop.')
param firewallIp string = '10.116.0.68'

@description('Identity VNet address prefix.')
param identityPrefix string = '10.116.4.0/24'

@description('Optional. When set, every network is targeted in this one subscription instead of the IDs in networks.json (for the test environment).')
param testSubscriptionId string = ''

var networks = loadJsonContent('networks.json')

var identity = union(networks.identity, empty(testSubscriptionId) ? {} : { subscriptionId: testSubscriptionId })

var sapNetworks = map(networks.sapNetworks, sap => union(sap, empty(testSubscriptionId) ? {} : { subscriptionId: testSubscriptionId }))

// =====================================================================
// Routes
// =====================================================================

// SAP -> Identity via Azure Firewall
var sapToIdentityRoutes = [
  {
    name: 'to-identity-vnet'
    properties: {
      addressPrefix: identityPrefix
      nextHopType: 'VirtualAppliance'
      nextHopIpAddress: firewallIp
    }
  }
]

// TCC PRD only: preserve the Internet exception from temp_all_88_221
var tccPrdInternetRoutes = [
  {
    name: 'to-88-221-internet'
    properties: {
      addressPrefix: '88.221.0.0/16'
      nextHopType: 'Internet'
    }
  }
]

// Identity -> each SAP VNet via Azure Firewall
var identityToSapRoutes = map(sapNetworks, sap => {
  name: sap.routeName
  properties: {
    addressPrefix: sap.addressPrefix
    nextHopType: 'VirtualAppliance'
    nextHopIpAddress: firewallIp
  }
})

// =====================================================================
// 1. SAP route tables
// =====================================================================

module sapRouting 'modules/route-table-association.bicep' = [for sap in sapNetworks: {
  name: 'tnalz01-rt-${toLower(sap.name)}'
  scope: resourceGroup(sap.subscriptionId, sap.resourceGroup)
  params: {
    routeTableName: sap.routeTableName
    vnetName: sap.vnetName
    subnetName: sap.subnetName
    routes: sap.name == 'TCC-PRD'
      ? concat(sapToIdentityRoutes, tccPrdInternetRoutes)
      : sapToIdentityRoutes
  }
}]

// =====================================================================
// 2. Identity route table (after SAP, matching the script's order)
// =====================================================================

module identityRouting 'modules/route-table-association.bicep' = {
  name: 'tnalz01-rt-identity'
  scope: resourceGroup(identity.subscriptionId, identity.resourceGroup)
  params: {
    routeTableName: identity.routeTableName
    vnetName: identity.vnetName
    subnetName: identity.subnetName
    routes: identityToSapRoutes
  }
  dependsOn: [
    sapRouting
  ]
}
