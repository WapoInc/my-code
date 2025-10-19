

param stgaccName string = 'shemo2'
param location string = 'SouthAfricaNorth'

resource stgacc 'Microsoft.Storage/storageAccounts@2021-08-01' ={
  name: stgaccName
  location: location
  sku: {
    name:'Standard_LRS' 
  }
  kind: 'StorageV2'
}
