
@description('Enter a unique name')
param stgacc string

@description('Enter the location fro the Storage Account')
param loc string 

resource storageacc 'Microsoft.Storage/storageAccounts@2021-08-01' = {
  name: stgacc
  location: loc
  sku: {
    name: 'Premium_LRS'
  }
  kind: 'StorageV2'
}
