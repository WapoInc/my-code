//
//
// az deployment sub create \
//   --subscription "0cfd0d2a-2b38-4c93-ba14-cf79185bc683" \
//   --name "deploy-global-vwan" \
//   --location "southafricanorth" \
//   --template-file "./@-Azure-CLI/@-My-AIRS-Infra-as-Code/My-Labs/1-MngEnv461963.onmicrosoft.com/Global-vWAN-rg.bicep"




targetScope = 'subscription'

@description('Name of the resource group to create.')
param resourceGroupName string = 'SA-North-vWAN'

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
    tags: tags
  }
}

output resourceGroupName string = resourceGroup.name
output resourceGroupId string = resourceGroup.id
output virtualWanId string = virtualWanResources.outputs.virtualWanId
output virtualHubId string = virtualWanResources.outputs.virtualHubId
