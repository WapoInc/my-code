targetScope = 'subscription'

param rgName string = 'rg-vmr-sa-North'
param location string = 'southafricanorth'

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: rgName
  location: location
}
