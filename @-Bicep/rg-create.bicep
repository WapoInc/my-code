targetScope = 'subscription'

resource my_rg 'Microsoft.Resources/resourceGroups@2020-10-01' ={
  name: 'vmr-rg-test2'
  location: 'southafricawest'
}
