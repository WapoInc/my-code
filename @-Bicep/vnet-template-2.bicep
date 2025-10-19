

param virtualNetworks_10_222_name string = '10-222'

resource virtualNetworks_10_222_name_resource 'Microsoft.Network/virtualNetworks@2020-08-01' = {
  name: virtualNetworks_10_222_name
  location: 'southafricanorth'
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.222.0.0/24'
      ]
    }
    subnets: [
      {
        name: 'SubNet-1'
        properties: {
          addressPrefix: '10.222.0.0/25'
          delegations: []
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: 'SubNet-2'
        properties: {
          addressPrefix: '10.222.0.128/25'
          serviceEndpoints: []
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

resource virtualNetworks_10_222_name_SubNet_1 'Microsoft.Network/virtualNetworks/subnets@2020-08-01' = {
  name: '${virtualNetworks_10_222_name_resource.name}/SubNet-1'
  properties: {
    addressPrefix: '10.222.0.0/25'
    delegations: []
    privateEndpointNetworkPolicies: 'Enabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
}

resource virtualNetworks_10_222_name_SubNet_2 'Microsoft.Network/virtualNetworks/subnets@2020-08-01' = {
  name: '${virtualNetworks_10_222_name_resource.name}/SubNet-2'
  properties: {
    addressPrefix: '10.222.0.128/25'
    serviceEndpoints: []
    delegations: []
    privateEndpointNetworkPolicies: 'Enabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
}
