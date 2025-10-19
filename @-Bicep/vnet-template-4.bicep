param vnet_name string = 'vnet123'
param subnet_name string = 'subnet01'
param ip_address_space string = '123.1.0.0/16'
param subnet_1_prefix string = '123.1.1.0/24'


resource vnet_build 'Microsoft.Network/virtualNetworks@2020-08-01' = {
  name: vnet_name
  location: 'southafricanorth'
  properties: {
    addressSpace: {
      addressPrefixes: [
        ip_address_space
      ]
    }
    subnets: [
      {
        name: subnet_name
        properties: {
          addressPrefix: subnet_1_prefix
          delegations: []
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
    virtualNetworkPeerings: []
    enableDdosProtection: false
  }
}

resource subnet_build 'Microsoft.Network/virtualNetworks/subnets@2020-08-01' = {
  name: subnet_name
  properties: {
    addressPrefix: subnet_1_prefix
    delegations: []
    privateEndpointNetworkPolicies: 'Enabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
}
