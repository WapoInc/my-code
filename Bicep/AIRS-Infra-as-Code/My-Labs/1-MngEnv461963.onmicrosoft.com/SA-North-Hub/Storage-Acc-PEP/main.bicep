targetScope = 'resourceGroup'

@description('Region for all resources.')
param location string = 'southafricanorth'

@description('Existing VNet that hosts the private endpoint subnet.')
param vnetName string = 'southafricanorth-vnet'

@description('Resource group of the existing VNet. Defaults to this RG.')
param vnetResourceGroupName string = resourceGroup().name

@description('Existing subnet used for private endpoints.')
param subnetName string = 'Priv-end-points'

@description('Globally unique storage account name (3-24 lowercase alphanumeric).')
@minLength(3)
@maxLength(24)
param storageAccountName string = 'litstorageacc1'

@allowed([ 'Standard_LRS', 'Standard_ZRS', 'Standard_GRS' ])
param storageSku string = 'Standard_LRS'

param tags object = {
  env: 'dev'
  owner: 'WapoInc'
}

var groups = [ 'blob', 'file' ]

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  name: vnetName
  scope: resourceGroup(vnetResourceGroupName)
}

resource peSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' existing = {
  parent: vnet
  name: subnetName
}

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: { name: storageSku }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    publicNetworkAccess: 'Enabled'
    networkAcls: { bypass: 'None', defaultAction: 'Allow' }
  }
}

resource dnsZones 'Microsoft.Network/privateDnsZones@2020-06-01' = [for group in groups: {
  name: 'privatelink.${group}.${environment().suffixes.storage}'
  location: 'global'
  tags: tags
}]

resource dnsLinks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = [for (group, index) in groups: {
  name: '${dnsZones[index].name}/link-${vnetName}'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: vnet.id }
  }
}]

resource privateEndpoints 'Microsoft.Network/privateEndpoints@2023-11-01' = [for group in groups: {
  name: 'pe-${storageAccountName}-${group}'
  location: location
  tags: tags
  properties: {
    subnet: { id: peSubnet.id }
    privateLinkServiceConnections: [
      {
        name: 'plsc-${storageAccountName}-${group}'
        properties: {
          privateLinkServiceId: storage.id
          groupIds: [ group ]
        }
      }
    ]
  }
}]

resource peDnsGroups 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01' = [for (group, index) in groups: {
  name: '${privateEndpoints[index].name}/default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: '${group}-config'
        properties: { privateDnsZoneId: dnsZones[index].id }
      }
    ]
  }
}]

output storageAccountId string = storage.id
output privateEndpointIds array = [for (group, index) in groups: privateEndpoints[index].id]
output fqdns array = [
  '${storageAccountName}.blob.${environment().suffixes.storage}'
  '${storageAccountName}.file.${environment().suffixes.storage}'
]
