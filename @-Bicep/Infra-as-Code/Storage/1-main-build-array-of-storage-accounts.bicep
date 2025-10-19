
// Create many resources using 'array'
param storageNameArray array = [
  'vmrstorage011'
  'vmrstorage022'
  'vmrstorage033'
  'vmrstorage044'
]

param location string = 'SouthAfricaNorth'

resource storage 'Microsoft.Storage/storageAccounts@2021-04-01' = [for store in storageNameArray: {
  name: '${store}'
  location: location
  sku: {
    name: 'Premium_LRS'
  }
  kind: 'StorageV2'
}]


