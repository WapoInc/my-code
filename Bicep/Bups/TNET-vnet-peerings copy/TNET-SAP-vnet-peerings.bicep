// TNET - peer SAP spoke VNets (in two different subscriptions) to the hub VNet in a third subscription.
// Cross-subscription peering: each peering is written into its own VNet's subscription via a scoped module.
// Deploy at subscription scope: az deployment sub create --location <region> --subscription <hubSub> ...

targetScope = 'subscription'

@description('Location for hub gateway resources (public IP and ExpressRoute gateway).')
param location string = 'southafricanorth'

@description('Subscription that contains the hub VNet.')
param hubSubscriptionId string
@description('Resource group that contains the hub VNet.')
param hubResourceGroup string
@description('Name of the hub VNet.')
param hubVnetName string

@description('Subscription that contains the first spoke VNet.')
param spoke2SubscriptionId string
param spoke2ResourceGroup string
param spoke2VnetName string

@description('Subscription that contains the second spoke VNet.')
param spoke3SubscriptionId string
param spoke3ResourceGroup string
param spoke3VnetName string

@description('Set true only when the hub VNet has a VPN/ExpressRoute gateway to share with the spokes.')
param hubHasGateway bool = false

@description('Allow traffic forwarded (not originating) from the peered VNet.')
param allowForwardedTraffic bool = true

@description('Deploy the hub subnet layout, public IP, and ExpressRoute gateway.')
param deployHubGateway bool = true

var hubVnetId = resourceId(hubSubscriptionId, hubResourceGroup, 'Microsoft.Network/virtualNetworks', hubVnetName)
var spoke2VnetId = resourceId(spoke2SubscriptionId, spoke2ResourceGroup, 'Microsoft.Network/virtualNetworks', spoke2VnetName)
var spoke3VnetId = resourceId(spoke3SubscriptionId, spoke3ResourceGroup, 'Microsoft.Network/virtualNetworks', spoke3VnetName)

// Hub subnets, public IP, and ExpressRoute gateway (all in the hub subscription).
module hubNetwork 'modules/hub-network.bicep' = if (deployHubGateway) {
  name: 'tnet-hub-network'
  scope: resourceGroup(hubSubscriptionId, hubResourceGroup)
  params: {
    location: location
    hubVnetName: hubVnetName
  }
}

// Hub side: one peering per spoke, optionally advertising the hub gateway.
module hubPeerings 'modules/hub-peerings.bicep' = {
  name: 'tnet-hub-peerings'
  scope: resourceGroup(hubSubscriptionId, hubResourceGroup)
  params: {
    hubVnetName: hubVnetName
    peering1Name: 'peer-to-sap-vnet-${spoke2VnetName}'
    remoteVnet1Id: spoke2VnetId
    peering2Name: 'peer-to-sap-vnet-${spoke3VnetName}'
    remoteVnet2Id: spoke3VnetId
    allowForwardedTraffic: allowForwardedTraffic
    allowGatewayTransit: hubHasGateway
  }
  dependsOn: [
    hubNetwork
  ]
}

// Spoke side: consume the hub gateway only after the hub peering enables gateway transit.
module spoke2Peering 'modules/spoke-peering.bicep' = {
  name: 'tnet-spoke2-to-hub'
  scope: resourceGroup(spoke2SubscriptionId, spoke2ResourceGroup)
  params: {
    localVnetName: spoke2VnetName
    peeringName: 'peer-to-sap-vnet-${hubVnetName}'
    remoteVnetId: hubVnetId
    allowForwardedTraffic: allowForwardedTraffic
    useRemoteGateways: hubHasGateway
  }
  dependsOn: [
    hubPeerings
  ]
}

module spoke3Peering 'modules/spoke-peering.bicep' = {
  name: 'tnet-spoke3-to-hub'
  scope: resourceGroup(spoke3SubscriptionId, spoke3ResourceGroup)
  params: {
    localVnetName: spoke3VnetName
    peeringName: 'peer-to-sap-vnet-${hubVnetName}'
    remoteVnetId: hubVnetId
    allowForwardedTraffic: allowForwardedTraffic
    useRemoteGateways: hubHasGateway
  }
  dependsOn: [
    hubPeerings
  ]
}
