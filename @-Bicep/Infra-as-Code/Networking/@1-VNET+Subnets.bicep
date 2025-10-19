// This will build a Virtual Network + 2 Subnets


param location string = resourceGroup().location

@description('Enter all the VNET and Subnet settings')
var vnet1config = {
  name: 'vNet1'
  addressSpacePrefix: '172.16.0.0/12'
  subnetName1: 'SubNet-1'
  subnetPrefix1: '172.16.1.0/24'
  subnetName2: 'SubNet-2'
  subnetPrefix2: '172.16.2.0/24'
  // subnetName3: 'GatewaySubnet'
  // subnetPrefix3: '172.16.0.0/27'
}


resource vnet 'Microsoft.Network/virtualNetworks@2020-06-01' = {
  name: vnet1config.name
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnet1config.addressSpacePrefix
      ]
    }
    subnets: [
      {
        name: vnet1config.subnetName1
        properties: {
          addressPrefix: vnet1config.subnetPrefix1
        }
      }
      {
        name: vnet1config.subnetName2
        properties: {
          addressPrefix: vnet1config.subnetPrefix2
        }
      }
      // {
      //   name: vnet1config.subnetName3
      //   properties: {
      //     addressPrefix: vnet1config.subnetPrefix3
      //   }
      // }
    ]
  }
}


