// ============================================================
// SA-North-vWAN - Resource Group + vWAN Hub in SA North
// ============================================================
//
// run these lines to create RG and call Resources script
//
// ./deploy-global-vwan.sh what-if
// ./deploy-global-vwan.sh deploy

targetScope = 'subscription'

@description('Name of the resource group to create.')
param resourceGroupName string = 'Global-vWAN'

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

resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-11-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

module virtualWanResources 'Global-vWAN-resources.bicep' = {
  name: 'deploy-global-vwan'
  scope: resourceGroup
  params: {
    location: location
    virtualWanName: virtualWanName
    virtualHubName: virtualHubName
    virtualHubAddressPrefix: virtualHubAddressPrefix
    spokeVmAdminPassword: spokeVmAdminPassword
    tags: tags
  }
}

output resourceGroupName string = resourceGroup.name
output resourceGroupId string = resourceGroup.id
output virtualWanId string = virtualWanResources.outputs.virtualWanId
output virtualHubId string = virtualWanResources.outputs.virtualHubId
