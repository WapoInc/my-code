// read -s ADMIN_PASSWORD
// az deployment sub create -l southafricawest \
//   -f ZAW-Hub-VM-vnet-er-gw-v5-rg.bicep \
//   -p location=southafricawest adminPassword="$ADMIN_PASSWORD"
// unset ADMIN_PASSWORD

targetScope = 'subscription'

@description('Name of the resource group to create.')
param resourceGroupName string = 'SA-West-region-bicep'

@description('Azure region for the resource group and all resources.')
param location string = 'southafricawest'

@secure()
@description('Administrator password for the virtual machine.')
param adminPassword string

@description('Create the connection to the existing ExpressRoute circuit.')
param deployExpressRouteConnection bool = true

@description('Name of the existing ExpressRoute circuit.')
param circuitName string = 'ER-LTSA-SA-West'

@description('Resource group containing the existing ExpressRoute circuit.')
param circuitResourceGroupName string = 'ER-LTSA-rg'

@description('Subscription containing the existing ExpressRoute circuit.')
param circuitSubscriptionId string = subscription().subscriptionId

resource resourceGroup 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: resourceGroupName
  location: location
}

module hubResources 'ZAW-Hub-VM-vnet-er-gw-v5-resources.bicep' = {
  scope: resourceGroup
  params: {
    location: location
    adminPassword: adminPassword
    deployExpressRouteConnection: deployExpressRouteConnection
    circuitName: circuitName
    circuitResourceGroupName: circuitResourceGroupName
    circuitSubscriptionId: circuitSubscriptionId
  }
}

output resourceGroupName string = resourceGroup.name
output vnetId string = hubResources.outputs.vnetId
output vmPrivateIp string = hubResources.outputs.vmPrivateIp
output expressRouteGatewayId string = hubResources.outputs.expressRouteGatewayId
output expressRouteConnectionId string = hubResources.outputs.expressRouteConnectionId
