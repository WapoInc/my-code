// tnet-new-alz-peerings: peer any number of ALZ spoke VNets (across subscriptions) to a hub VNet.
// Cross-subscription: each peering is written into its own VNet's subscription via a scoped module loop.
// Deploy at subscription scope: az deployment sub create --location <region> --subscription <hubSub> ...

targetScope = 'subscription'

@description('Prefix applied to peering and deployment names.')
param namePrefix string = 'tnet-new-alz-peerings'

@description('Subscription that contains the hub VNet.')
param hubSubscriptionId string
@description('Resource group that contains the hub VNet.')
param hubResourceGroup string
@description('Name of the hub VNet.')
param hubVnetName string

@description('Allow traffic forwarded (not originating) from the peered VNet.')
param allowForwardedTraffic bool = true

@description('Enable gateway transit: hub advertises its gateway; spokes use the hub remote gateway.')
param hubHasGateway bool = false

@description('Spoke VNets to peer to the hub.')
param spokes spokeType[]

type spokeType = {
  subscriptionId: string
  resourceGroup: string
  vnetName: string
}

var hubVnetId = resourceId(hubSubscriptionId, hubResourceGroup, 'Microsoft.Network/virtualNetworks', hubVnetName)

// Hub-side peerings, serialized (batch size 1) to avoid superseded operations on the hub VNet.
@batchSize(1)
module hubToSpoke 'modules/peering.bicep' = [for (spoke, i) in spokes: {
  name: '${namePrefix}-hub-to-${i}'
  scope: resourceGroup(hubSubscriptionId, hubResourceGroup)
  params: {
    localVnetName: hubVnetName
    peeringName: '${namePrefix}-to-${spoke.vnetName}'
    remoteVnetId: resourceId(spoke.subscriptionId, spoke.resourceGroup, 'Microsoft.Network/virtualNetworks', spoke.vnetName)
    allowForwardedTraffic: allowForwardedTraffic
    allowGatewayTransit: hubHasGateway
    useRemoteGateways: false
  }
}]

// Spoke-side peerings; each consumes the hub gateway only after hub transit is enabled.
module spokeToHub 'modules/peering.bicep' = [for (spoke, i) in spokes: {
  name: '${namePrefix}-spoke-${i}-to-hub'
  scope: resourceGroup(spoke.subscriptionId, spoke.resourceGroup)
  params: {
    localVnetName: spoke.vnetName
    peeringName: '${namePrefix}-to-${hubVnetName}'
    remoteVnetId: hubVnetId
    allowForwardedTraffic: allowForwardedTraffic
    allowGatewayTransit: false
    useRemoteGateways: hubHasGateway
  }
  dependsOn: [
    hubToSpoke
  ]
}]
