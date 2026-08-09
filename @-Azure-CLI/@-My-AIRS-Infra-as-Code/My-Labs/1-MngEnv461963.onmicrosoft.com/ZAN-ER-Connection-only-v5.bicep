// ============================================================
// ER Connection ONLY - SA-North
// South Africa North  |  v5 - Bicep (resource-group scoped)
// ============================================================
// Run this AFTER the full hub (v5) has been deployed and the
// ExpressRoute gateway shows provisioningState = Succeeded.
// It creates ONLY the ExpressRoute connection between the existing
// gateway (in this RG) and the existing circuit.
//
// Deploy into the hub's resource group:
//   az deployment group create \
//     -g SA-North-region-bicep \
//     -f ZAN-ER-Connection-only-v5.bicep
//
// Prerequisites:
//   - ER gateway provisioningState = Succeeded
//   - ER circuit serviceProviderProvisioningState = Provisioned
//   - authorizationKey only needed for cross-subscription/tenant circuits
// ============================================================

targetScope = 'resourceGroup'

@description('Region of the connection (defaults to the RG location).')
param location string = resourceGroup().location

@description('Name for the ExpressRoute connection.')
param connectionName string = 'ER-SA-North-Connection'

@description('Name of the existing ExpressRoute gateway (in this resource group).')
param gatewayName string = 'ER-GateWay-SA-North-Standard'

@description('Name of the existing ExpressRoute circuit.')
param circuitName string = 'ER-LIT-ZAN'

@description('Resource group that contains the ExpressRoute circuit.')
param circuitResourceGroup string = 'ER-LTSA-rg'

@description('Subscription ID of the circuit (defaults to the current subscription).')
param circuitSubscriptionId string = subscription().subscriptionId

@description('Routing weight for the connection.')
param routingWeight int = 0

@description('Authorization key - only needed for cross-subscription/tenant circuits.')
@secure()
param authorizationKey string = ''

// Existing ER gateway in this resource group (must already be deployed)
resource ergw 'Microsoft.Network/virtualNetworkGateways@2023-11-01' existing = {
  name: gatewayName
}

// Existing ER circuit (can be in another RG / subscription)
resource circuit 'Microsoft.Network/expressRouteCircuits@2023-11-01' existing = {
  name: circuitName
  scope: resourceGroup(circuitSubscriptionId, circuitResourceGroup)
}

// The ExpressRoute connection (the only resource created here)
resource erConnection 'Microsoft.Network/connections@2023-11-01' = {
  name: connectionName
  location: location
  properties: {
    connectionType: 'ExpressRoute'
    routingWeight: routingWeight
    // Only the resource id is used for these references
    #disable-next-line BCP035
    virtualNetworkGateway1: {
      id: ergw.id
    }
    peer: {
      id: circuit.id
    }
    authorizationKey: empty(authorizationKey) ? null : authorizationKey
  }
}

output connectionId string = erConnection.id
output connectionName string = erConnection.name
