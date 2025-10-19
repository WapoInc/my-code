
param vNetSettings object = {
  name: 'VNet1'
  location: 'SouthAfricaNorth'
  addressPrefixes: [
    {
      name: 'firstPrefix'
      addressPrefix: '10.0.0.0/8'
    }
    {
      name: 'secondPrefix'
      addressPrefix: '172.16.0.0/12'
    }

  ]
  subnets: [
    {
      name: 'GatewaySubnet'
      addressPrefix: '10.0.0.0/27'
    }
    {
      name: 'firstSubnet'
      addressPrefix: '10.0.1.0/24'
    }
    {
      name: 'secondSubnet'
      addressPrefix: '10.0.2.0/24'
    }
    {
      name: 'thirdSubnet'
      addressPrefix: '172.16.0.0/24'
    }
    {
      name: 'fourthSubnet'
      addressPrefix: '172.16.1.0/24'
    }
  ]
}

resource vnet 'Microsoft.Network/virtualNetworks@2020-06-01' = {
  name: vNetSettings.name
  location: vNetSettings.location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vNetSettings.addressPrefixes[0].addressPrefix
        vNetSettings.addressPrefixes[1].addressPrefix
      ]
    }
    subnets: [
      {
        name: vNetSettings.subnets[0].name
        properties: {
          addressPrefix: vNetSettings.subnets[0].addressPrefix
        }
      }
      {
        name: vNetSettings.subnets[1].name
        properties: {
          addressPrefix: vNetSettings.subnets[1].addressPrefix
        }
      }
      {
        name: vNetSettings.subnets[2].name
        properties: {
          addressPrefix: vNetSettings.subnets[2].addressPrefix
        }
      }
      {
        name: vNetSettings.subnets[3].name
        properties: {
          addressPrefix: vNetSettings.subnets[3].addressPrefix
        }
      }
      {
        name: vNetSettings.subnets[4].name
        properties: {
          addressPrefix: vNetSettings.subnets[4].addressPrefix
        }
      }
    ]
  }
}

