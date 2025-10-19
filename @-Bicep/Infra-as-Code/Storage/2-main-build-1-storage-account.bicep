
param stgacc string
param location string = resourceGroup().location


//   name: '${uniqueString(resourceGroup().name)}+${stgacc}'

resource storage 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: stgacc
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}
