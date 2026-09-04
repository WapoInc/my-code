// ============================================================
// SA-North-vWAN - Resource Group + vWAN Hub in SA North
// ============================================================
//
// run these lines to create RG and call Resources script
//
// ./deploy-global-vwan.sh what-if
// ./deploy-global-vwan.sh deploy
// ./deploy-global-vwan.sh full

targetScope = 'subscription'

@description('Name of the resource group to create.')
param resourceGroupName string = 'Global-vWAN-PoC'

@description('Unique name used for the nested resource deployment.')
param deploymentName string = 'deploy-global-vwan'

@description('Azure region for the resource group.')
param location string = 'southafricanorth'

@description('Resource tags applied to the resource group.')
param tags object = {}

@description('Name of the Azure Virtual WAN.')
param virtualWanName string = 'Global-vWAN'

@description('Name of the Azure Virtual Hub.')
param virtualHubName string = 'ZAN-Hub-1'

@description('Address prefix assigned to the Azure Virtual Hub.')
param virtualHubAddressPrefix string = '10.200.1.0/24'

@description('Administrator password for the Ubuntu VM.')
@secure()
param spokeVmAdminPassword string

@description('Size used by the Ubuntu spoke VMs in all regions.')
param spokeVmSize string = 'Standard_B1ms'

@description('Pre-shared key for the FortiGate site-to-site VPN connection.')
@secure()
param fortiGateVpnSharedKey string

@description('Name of the existing ExpressRoute circuit connected to the hub.')
param circuitName string = 'ER-Metro'

@description('Resource group containing the existing ExpressRoute circuit.')
param circuitResourceGroup string = 'ER-LTSA-rg'

@description('Subscription ID containing the existing ExpressRoute circuit.')
param circuitSubscriptionId string = subscription().subscriptionId

@description('Authorization key used when the ExpressRoute circuit is in another subscription.')
@secure()
param circuitAuthorizationKey string = ''

resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-11-01' = {
  name: resourceGroupName
  location: location
  tags: union(tags, {
    'NB!!!': 'vmr'
  })
}

module virtualWanResources 'Global-vWAN-resources.bicep' = {
  name: '${deploymentName}-resources'
  scope: resourceGroup
  params: {
    location: location
    virtualWanName: virtualWanName
    virtualHubName: virtualHubName
    virtualHubAddressPrefix: virtualHubAddressPrefix
    spokeVmAdminPassword: spokeVmAdminPassword
    spokeVmSize: spokeVmSize
    fortiGateVpnSharedKey: fortiGateVpnSharedKey
    circuitName: circuitName
    circuitResourceGroup: circuitResourceGroup
    circuitSubscriptionId: circuitSubscriptionId
    circuitAuthorizationKey: circuitAuthorizationKey
    tags: tags
  }
}

output resourceGroupName string = resourceGroup.name
output resourceGroupId string = resourceGroup.id
output virtualWanId string = virtualWanResources.outputs.virtualWanId
output virtualHubId string = virtualWanResources.outputs.virtualHubId
output vpnGatewayPublicIpAddresses object = {
  Interface0: virtualWanResources.outputs.vpnGatewayPublicIpAddresses[0]
  Interface1: virtualWanResources.outputs.vpnGatewayPublicIpAddresses[1]
}
