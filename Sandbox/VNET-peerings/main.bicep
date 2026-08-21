// Peers spoke 5 and spoke 6 to the existing hub VNet with VPN gateway transit.
// The hub is referenced as `existing`, so its VPN gateway and other spoke peerings are untouched.

targetScope = 'resourceGroup'

@description('Azure region for the spoke virtual networks.')
param location string = 'southafricanorth'

@description('Name of the existing hub virtual network that hosts the VPN gateway.')
param hubVnetName string = 'za-east-southafricanorth-vnet'

param spoke5VnetName string = 'za-east-spoke-5-vnet'
param spoke5VnetPrefix string = '10.24.0.0/24'
param spoke5SubnetName string = 'Subnet-1'
param spoke5SubnetPrefix string = '10.24.0.0/25'

param spoke6VnetName string = 'za-east-spoke-6-vnet'
param spoke6VnetPrefix string = '10.25.0.0/24'
param spoke6SubnetName string = 'Subnet-1'
param spoke6SubnetPrefix string = '10.25.0.0/25'

param hubToSpoke5PeeringName string = 'hub-to-za-east-spoke-5'
param spoke5ToHubPeeringName string = 'za-east-spoke-5-to-hub'
param hubToSpoke6PeeringName string = 'hub-to-za-east-spoke-6'
param spoke6ToHubPeeringName string = 'za-east-spoke-6-to-hub'

resource hubVnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: hubVnetName
}

resource spoke5Vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: spoke5VnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        spoke5VnetPrefix
      ]
    }
    subnets: [
      {
        name: spoke5SubnetName
        properties: {
          addressPrefix: spoke5SubnetPrefix
        }
      }
    ]
  }
}

resource spoke6Vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: spoke6VnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        spoke6VnetPrefix
      ]
    }
    subnets: [
      {
        name: spoke6SubnetName
        properties: {
          addressPrefix: spoke6SubnetPrefix
        }
      }
    ]
  }
}

// Hub side advertises the VPN gateway to the spoke.
resource hubToSpoke5 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = {
  parent: hubVnet
  name: hubToSpoke5PeeringName
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: true
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: spoke5Vnet.id
    }
  }
}

// Spoke side consumes the hub remote gateway; it must follow the hub transit peering.
resource spoke5ToHub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = {
  parent: spoke5Vnet
  name: spoke5ToHubPeeringName
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: true
    remoteVirtualNetwork: {
      id: hubVnet.id
    }
  }
  dependsOn: [
    hubToSpoke5
  ]
}

resource hubToSpoke6 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = {
  parent: hubVnet
  name: hubToSpoke6PeeringName
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: true
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: spoke6Vnet.id
    }
  }
  // Serialize hub-side peering writes to avoid superseded operations on the hub VNet.
  dependsOn: [
    hubToSpoke5
  ]
}

resource spoke6ToHub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = {
  parent: spoke6Vnet
  name: spoke6ToHubPeeringName
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: true
    remoteVirtualNetwork: {
      id: hubVnet.id
    }
  }
  dependsOn: [
    hubToSpoke6
  ]
}

output hubVnetId string = hubVnet.id
output spoke5VnetId string = spoke5Vnet.id
output spoke6VnetId string = spoke6Vnet.id
