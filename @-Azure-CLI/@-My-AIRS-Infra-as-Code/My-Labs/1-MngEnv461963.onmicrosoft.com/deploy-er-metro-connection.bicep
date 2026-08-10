/* Copy and paste into Bash from this directory:
// az deployment group create \
//   --resource-group SA-North-region \
//   --name deploy-er-metro-connection \
//   --template-file deploy-er-metro-connection.bicep
// */

targetScope = 'resourceGroup'

@description('Azure region of the existing ExpressRoute gateway.')
param location string = 'southafricanorth'

@description('Name of the existing ExpressRoute virtual network gateway.')
param gatewayName string = 'ER-GateWay-SA-North-Standard'

@description('Name of the ExpressRoute connection to create.')
param connectionName string = 'ER-Metro-Conn-to-ER-GateWay-SA-North-Standard'

@description('Resource ID of the existing ExpressRoute circuit.')
param circuitResourceId string = '/subscriptions/0cfd0d2a-2b38-4c93-ba14-cf79185bc683/resourceGroups/ER-LTSA-rg/providers/Microsoft.Network/expressRouteCircuits/ER-Metro'

@description('Routing weight for the ExpressRoute connection.')
param routingWeight int = 0

resource expressRouteGateway 'Microsoft.Network/virtualNetworkGateways@2024-05-01' existing = {
  name: gatewayName
}

resource expressRouteConnection 'Microsoft.Network/connections@2024-05-01' = {
  name: connectionName
  location: location
  properties: {
    connectionType: 'ExpressRoute'
    routingWeight: routingWeight
    #disable-next-line BCP035
    virtualNetworkGateway1: {
      id: expressRouteGateway.id
    }
    peer: {
      id: circuitResourceId
    }
  }
}

output connectionName string = expressRouteConnection.name
output connectionId string = expressRouteConnection.id
output gatewayId string = expressRouteGateway.id
output circuitId string = circuitResourceId
