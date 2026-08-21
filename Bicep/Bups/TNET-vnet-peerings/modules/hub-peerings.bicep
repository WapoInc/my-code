// Creates both hub-side peerings (hub -> each spoke) on an existing hub VNet.
targetScope = 'resourceGroup'

param hubVnetName string
param peering1Name string
param remoteVnet1Id string
param peering2Name string
param remoteVnet2Id string
param allowForwardedTraffic bool = true
param allowGatewayTransit bool = false

resource hubVnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: hubVnetName
}

resource peering1 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = {
  parent: hubVnet
  name: peering1Name
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: allowForwardedTraffic
    allowGatewayTransit: allowGatewayTransit
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: remoteVnet1Id
    }
  }
}

// Serialize writes to the same hub VNet to avoid superseded peering operations.
resource peering2 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = {
  parent: hubVnet
  name: peering2Name
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: allowForwardedTraffic
    allowGatewayTransit: allowGatewayTransit
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: remoteVnet2Id
    }
  }
  dependsOn: [
    peering1
  ]
}
