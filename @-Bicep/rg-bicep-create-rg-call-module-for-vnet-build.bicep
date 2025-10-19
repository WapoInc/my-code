targetScope = 'subscription'

param rgName string = 'rg-vmr-sa-North'
param rgLocation string = 'SouthAfricaNorth'

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: rgName
  location: rgLocation
}
