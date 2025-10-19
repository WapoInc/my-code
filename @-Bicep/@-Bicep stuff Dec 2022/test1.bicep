

//#az group create -g vmr-Bicep-rg1 --location SouthAfricaNorth

//#az deployment group create --name vmrdep01 -f .\test1.bicep -g vmr-Bicep-rg1



param vnet string = 'vnet01'
param location string = 'southafricanorth'




  resource virtualNetwork 'Microsoft.Network/virtualNetworks@2019-11-01' = {
    name: vnet
    location: location
    properties: {
      addressSpace: {
        addressPrefixes: [
          '10.0.0.0/16'
        ]
      }
      subnets: [
        {
          name: 'Subnet-1'
          properties: {
            addressPrefix: '10.0.0.0/24'
          }
        }
        {
          name: 'Subnet-2'
          properties: {
            addressPrefix: '10.0.1.0/24'
          }
        }
      ]
    }
  }
  