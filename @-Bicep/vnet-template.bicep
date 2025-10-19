param vNET_name string = 'West-EU-Spoke-2'

resource vWAN_Spokes 'Microsoft.Network/virtualNetworks@2020-08-01' = {
  name: vNET_name
  location: 'southafricawest'
  properties: {
    addressSpace: {
      addressPrefixes: [
        '172.23.8.128/25'
      ]
    }
    subnets: [
      {
        name: 'SubNet-1'
        properties: {
          addressPrefix: '172.23.8.128/26'
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

resource vNET_name_SubNet_1 'Microsoft.Network/virtualNetworks/subnets@2020-08-01' = {
  name: '${vWAN_Spokes.name}/SubNet-1'
  properties: {
    addressPrefix: '172.23.8./26'
    delegations: []
    privateEndpointNetworkPolicies: 'Enabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
}
