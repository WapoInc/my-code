param vnetName string = 'myVNet'
param location string = 'eastus'
param addressPrefix string = '10.10.0.0/22'

resource vnet 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
  }
}

resource subnet1 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' = {
  name: 'Subnet1'
  dependsOn: [
    vnet
  ]
  properties: {
    addressPrefix: '10.10.0.0/24'
    serviceEndpoints: []
  }
}

resource subnet2 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' = {
  name: 'Subnet2'
  dependsOn: [
    vnet
  ]
  properties: {
    addressPrefix: '10.10.1.0/24'
    serviceEndpoints: []
  }
}
