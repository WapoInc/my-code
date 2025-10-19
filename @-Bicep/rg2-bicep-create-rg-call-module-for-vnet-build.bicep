targetScope = 'subscription'

param rgName string = 'rg-vmr123'
param rgLocation string = 'SouthAfricaNorth'

resource rgName_resourceGroup 'Microsoft.Resources/resourceGroups@2019-10-01' = {
  location: rgLocation
  name: rgName
}

// module buildvnet 'vnet-template-4.bicep' = {
//  scope: rgName_resourceGroup
//  name: 'vnetdep5'
// }
