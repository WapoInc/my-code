// ============================================================
// SA-North ExpressRoute Connection (module)
// South Africa North  |  v4 - Bicep (resource-group scoped)
// ============================================================
// Creates an ExpressRoute connection linking an EXISTING ER gateway
// (in this resource group) to an EXISTING ER circuit (which may live
// in a different resource group / subscription).
//
// Prerequisites:
//   - ER gateway provisioning state = Succeeded
//   - ER circuit serviceProviderProvisioningState = Provisioned
//   - If the circuit is in another subscription/tenant, supply an
//     authorization key created on that circuit.
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

@description('Authorization key — only needed for cross-subscription/tenant circuits.')
@secure()
param authorizationKey string = ''

// Existing ER gateway in this resource group
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
