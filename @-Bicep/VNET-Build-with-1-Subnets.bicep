param vnetname string 
param location string = 'SouthAfricaNorth'
param ipprefix string 
param subnetname1 string = 'SubNet-1'
param subnetprefix1 string


resource myvnet 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: vnetname
  location: location
  properties:{
    addressSpace:{
      addressPrefixes:[
        ipprefix
      ]
    }
    subnets:[
      {
        name:subnetname1
        properties:{
          addressPrefix: subnetprefix1
        }
      }
    ]
  }
}
