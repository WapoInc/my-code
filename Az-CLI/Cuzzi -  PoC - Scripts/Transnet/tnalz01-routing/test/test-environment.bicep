// =====================================================================
// TNALZ01 TEST ENVIRONMENT - pre-remediation state
//
// Deploys into ONE subscription, using the same resource names as
// production (from ../networks.json), so ../main.bicep can be tested
// against it with testSubscriptionId.
//
// Deploys:
//   - Hub VNet 10.116.0.0/22 with AzureFirewallSubnet 10.116.0.64/26
//     (Azure Firewall gets 10.116.0.68 when deployFirewall = true)
//   - Identity VNet + 9 SAP VNets, each peered to the hub
//   - An NSG on every spoke subnet and tags on every route table, so you
//     can check the remediation preserves them
//   - Route tables in the BEFORE state:
//       SAP:      0.0.0.0/0 -> firewall
//       Identity: 0.0.0.0/0 -> firewall, 10.116.4.0/24 -> firewall (self-route)
//       TCC-PRD:  subnet attached to temp_all_88_221
//                 (0.0.0.0/0 -> firewall, 88.221.0.0/16 -> Internet);
//                 rt-tnalz01-tcc-sap-prd-1 exists but is not attached
// =====================================================================

targetScope = 'subscription'

param location string = 'southafricanorth'

@description('Deploy a real Azure Firewall (Standard, roughly USD 1.25/hour plus data). Not needed to test route tables.')
param deployFirewall bool = false

param firewallIp string = '10.116.0.68'

param hubResourceGroup string = 'rg-tnalz01-hub-test'

param tags object = {
  environment: 'test'
  purpose: 'tnalz01-route-remediation-test'
}

var networks = loadJsonContent('../networks.json')

var defaultRouteToFirewall = {
  name: 'default-to-firewall'
  properties: {
    addressPrefix: '0.0.0.0/0'
    nextHopType: 'VirtualAppliance'
    nextHopIpAddress: firewallIp
  }
}

var spokes = concat(
  [
    union(networks.identity, {
      name: 'IDENTITY'
      routes: [
        defaultRouteToFirewall
        {
          name: 'identity-self-route'
          properties: {
            addressPrefix: networks.identity.addressPrefix
            nextHopType: 'VirtualAppliance'
            nextHopIpAddress: firewallIp
          }
        }
      ]
      legacyRouteTable: null
    })
  ],
  map(networks.sapNetworks, sap => union(sap, {
    routes: [
      defaultRouteToFirewall
    ]
    legacyRouteTable: sap.name == 'TCC-PRD'
      ? {
          name: 'temp_all_88_221'
          routes: [
            defaultRouteToFirewall
            {
              name: 'all-88-221'
              properties: {
                addressPrefix: '88.221.0.0/16'
                nextHopType: 'Internet'
              }
            }
          ]
        }
      : null
  }))
)

// ---------------------------------------------------------------------
// Resource groups
// ---------------------------------------------------------------------

resource hubRg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: hubResourceGroup
  location: location
  tags: tags
}

resource spokeRgs 'Microsoft.Resources/resourceGroups@2024-03-01' = [for spoke in spokes: {
  name: spoke.resourceGroup
  location: location
  tags: tags
}]

// ---------------------------------------------------------------------
// Hub
// ---------------------------------------------------------------------

module hub 'modules/hub.bicep' = {
  name: 'tnalz01-test-hub'
  scope: hubRg
  params: {
    location: location
    tags: tags
    deployFirewall: deployFirewall
  }
}

// ---------------------------------------------------------------------
// Spokes (Identity + SAP)
// ---------------------------------------------------------------------

module spokeNetworks 'modules/spoke.bicep' = [for (spoke, i) in spokes: {
  name: 'tnalz01-test-spoke-${toLower(spoke.name)}'
  scope: spokeRgs[i]
  params: {
    location: location
    tags: tags
    vnetName: spoke.vnetName
    subnetName: spoke.subnetName
    addressPrefix: spoke.addressPrefix
    routeTableName: spoke.routeTableName
    routes: spoke.routes
    legacyRouteTable: spoke.legacyRouteTable
    hubVnetId: hub.outputs.vnetId
  }
}]

// Hub -> spoke peerings, one at a time to avoid conflicting updates on the hub VNet
@batchSize(1)
module hubPeerings 'modules/hub-peering.bicep' = [for (spoke, i) in spokes: {
  name: 'tnalz01-test-peer-${toLower(spoke.name)}'
  scope: hubRg
  params: {
    hubVnetName: hub.outputs.vnetName
    spokeName: toLower(spoke.name)
    spokeVnetId: spokeNetworks[i].outputs.vnetId
  }
}]

output firewallPrivateIp string = deployFirewall ? hub.outputs.firewallPrivateIp : 'not deployed (routes still point to ${firewallIp})'
