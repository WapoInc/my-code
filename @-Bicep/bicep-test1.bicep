
param vnetPrefix string = '172.20.0.0/16'
param suffix string = 'Shemo-Again2'

var vnetName = 'vnet-${suffix}'

resource vnet 'Microsoft.Network/virtualNetworks@2019-12-01' = {
  name: vnetName
  location: resourceGroup().location
  tags: {
    Owner: 'vmr'
    CostCenter: '0181'
    CostValue: '$100'
  }
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetPrefix
      ]
    }
    subnets: [
      {
        name: 'SubNet-01'
        properties: {
          addressPrefix: '172.20.1.0/24'
        }
      }
      {
        name: 'SubNet-02'
        properties: {
          addressPrefix: '172.20.2.0/24'
        }
      }
      {
        name: 'Gatewaysubnet'
        properties: {
          addressPrefix: '172.20.0.0/24'
        }
      }
    ]
  }
}  
