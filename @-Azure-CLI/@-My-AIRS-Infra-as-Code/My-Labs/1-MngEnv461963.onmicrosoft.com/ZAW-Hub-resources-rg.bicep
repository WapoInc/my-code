// ============================================================
// SA-West-HUB - Resource Group + VNet + Subnets + ER GW + ER Connection + VM
// South Africa West  |  v5 - Bicep (subscription-scoped, creates the RG)
// ============================================================
// This is the hub orchestrator: it creates the resource group and
// deploys all hub resources (including the ExpressRoute connection)
// via the ZAW-Hub-VM-vnet-er-gw-v5-resources module.
//
// az deployment sub create \
//   -l southafricawest \
//   -f ZAW-Hub-resources-rg.bicep \
//   -p adminPassword='P@ssw0rd123!'
//
//
// NOTE: The ExpressRoute Gateway typically takes 20-45 minutes to provision;
// the ER connection is created automatically once the gateway is ready.
// ============================================================

targetScope = 'subscription'

@description('Name of the resource group to create.')
param resourceGroupName string = '${location}-region'

@description('Azure region for the resource group and all resources.')
param location string = deployment().location

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

@description('Authorization key for a circuit in another subscription/tenant. Required for cross-subscription or cross-tenant connections; leave empty for a circuit in the same subscription.')
@secure()
param authorizationKey string = ''

resource resourceGroup 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: resourceGroupName
  location: location
}

module hubResources 'ZAW-Hub-resources.bicep' = {
  scope: resourceGroup
  params: {
    location: location
    adminPassword: adminPassword
    deployExpressRouteConnection: deployExpressRouteConnection
    circuitName: circuitName
    circuitResourceGroupName: circuitResourceGroupName
    circuitSubscriptionId: circuitSubscriptionId
    authorizationKey: authorizationKey
  }
}

output resourceGroupName string = resourceGroup.name
output vnetId string = hubResources.outputs.vnetId
output vmPrivateIp string = hubResources.outputs.vmPrivateIp
output expressRouteGatewayId string = hubResources.outputs.expressRouteGatewayId
output expressRouteConnectionId string = hubResources.outputs.expressRouteConnectionId
