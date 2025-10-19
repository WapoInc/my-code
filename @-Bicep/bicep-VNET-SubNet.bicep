

param vnetIPPrefix string
param Suffix1 string ='vmr2'
param Suffix2 string ='VNET2'
param loc string = 'SouthAfricaNorth'
param subnet1 string

var myvNETName = 'vnet-${Suffix1}-${Suffix2}'

resource vnet 'Microsoft.Network/virtualnetworks@2015-05-01-preview' ={
  name: myvNETName
  location: loc
  properties: {
    addressSpace:{
      addressPrefixes: [
        vnetIPPrefix
      ]
    }
    subnets: [
      {
        name: 'SubNet-01'
        properties: {
          addressPrefix: subnet1
        }
      }
    ]
  }
}

