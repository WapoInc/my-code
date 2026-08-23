targetScope = 'resourceGroup'

@description('Azure region of the existing VPN gateway.')
param location string = resourceGroup().location

@description('Name of the existing route-based VPN gateway in the hub VNet.')
param vpnGatewayName string

@description('Name of the local network gateway that represents the on-premises FortiGate.')
param localNetworkGatewayName string

@description('Public IP address of the on-premises FortiGate.')
param onPremisesGatewayIpAddress string

@description('On-premises address prefixes reachable behind the FortiGate.')
param onPremisesAddressPrefixes array

@description('Name of the site-to-site IPsec connection.')
param connectionName string

@description('IPsec pre-shared key shared with the FortiGate.')
@secure()
param sharedKey string

resource vpnGateway 'Microsoft.Network/virtualNetworkGateways@2024-05-01' existing = {
  name: vpnGatewayName
}

resource localNetworkGateway 'Microsoft.Network/localNetworkGateways@2024-05-01' = {
  name: localNetworkGatewayName
  location: location
  properties: {
    gatewayIpAddress: onPremisesGatewayIpAddress
    localNetworkAddressSpace: {
      addressPrefixes: onPremisesAddressPrefixes
    }
  }
}

// No ipsecPolicies block: Basic SKU negotiates the default IKEv2/IPsec policy,
// which matches the FortiGate proposal (AES256/SHA256/DHGroup2, 28800s IKE, 27000s IPsec).
resource connection 'Microsoft.Network/connections@2024-05-01' = {
  name: connectionName
  location: location
  properties: {
    connectionType: 'IPsec'
    enableBgp: false
    usePolicyBasedTrafficSelectors: false
    sharedKey: sharedKey
    virtualNetworkGateway1: {
      id: vpnGateway.id
      properties: {}
    }
    localNetworkGateway2: {
      id: localNetworkGateway.id
      properties: {}
    }
  }
}

output localNetworkGatewayId string = localNetworkGateway.id
output connectionId string = connection.id
