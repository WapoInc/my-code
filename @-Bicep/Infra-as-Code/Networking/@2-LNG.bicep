param location string = resourceGroup().location
param lngname string

@description('CIDR block representing the address space of the OnPremise VPN network\'s Subnet')
param localAddressPrefix array = [
  '192.168.2.0/24'
  '172.16.0.0/22'
]


resource lng 'Microsoft.Network/localNetworkGateways@2022-07-01' = {
  name: lngname
  location: location
  properties: {
    fqdn: 'za-east.fortiddns.com'
    localNetworkAddressSpace: {
       addressPrefixes: localAddressPrefix
    }
  }
}

