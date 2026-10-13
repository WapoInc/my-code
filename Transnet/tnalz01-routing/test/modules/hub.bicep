param location string
param tags object
param deployFirewall bool

param vnetName string = 'vnet-tnalz01-hub-test'

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.116.0.0/22'
      ]
    }
    subnets: [
      {
        // First usable IP in 10.116.0.64/26 is 10.116.0.68
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: '10.116.0.64/26'
        }
      }
    ]
  }
}

resource firewallPip 'Microsoft.Network/publicIPAddresses@2024-05-01' = if (deployFirewall) {
  name: 'pip-afw-tnalz01-hub-test'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource firewallPolicy 'Microsoft.Network/firewallPolicies@2024-05-01' = if (deployFirewall) {
  name: 'afwp-tnalz01-hub-test'
  location: location
  tags: tags
  properties: {
    sku: {
      tier: 'Standard'
    }
  }
}

resource ruleGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2024-05-01' = if (deployFirewall) {
  parent: firewallPolicy
  name: 'rcg-tnalz01-test'
  properties: {
    priority: 100
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'allow-sap-identity'
        priority: 100
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'sap-to-identity'
            ipProtocols: [
              'Any'
            ]
            sourceAddresses: [
              '10.116.6.0/23'
              '10.116.8.0/21'
            ]
            destinationAddresses: [
              '10.116.4.0/24'
            ]
            destinationPorts: [
              '*'
            ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'identity-to-sap'
            ipProtocols: [
              'Any'
            ]
            sourceAddresses: [
              '10.116.4.0/24'
            ]
            destinationAddresses: [
              '10.116.6.0/23'
              '10.116.8.0/21'
            ]
            destinationPorts: [
              '*'
            ]
          }
        ]
      }
    ]
  }
}

resource firewall 'Microsoft.Network/azureFirewalls@2024-05-01' = if (deployFirewall) {
  name: 'afw-tnalz01-hub-test'
  location: location
  tags: tags
  dependsOn: [
    ruleGroup
  ]
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: 'Standard'
    }
    firewallPolicy: {
      id: firewallPolicy.id
    }
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          subnet: {
            id: '${vnet.id}/subnets/AzureFirewallSubnet'
          }
          publicIPAddress: {
            id: firewallPip.id
          }
        }
      }
    ]
  }
}

output vnetId string = vnet.id
output vnetName string = vnet.name
output firewallPrivateIp string = deployFirewall ? firewall!.properties.ipConfigurations[0].properties.privateIPAddress : ''
