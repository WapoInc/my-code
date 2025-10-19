targetScope = 'subscription'

param rgName string
param rgLocation string = 'SouthAfricaNorth'

resource rgName_resource 'Microsoft.Resources/resourceGroups@2019-10-01' = {
  location: rgLocation
  name: rgName
  properties: {}
}
