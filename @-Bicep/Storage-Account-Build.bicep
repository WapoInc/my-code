

param stgaccName string 
param location string = 'SouthAfricaNorth'

resource stgacc 'Microsoft.Storage/storageAccounts@2021-08-01' = {
  name: stgaccName
  location: location
  kind:'StorageV2'
  sku:{
    name:'Standard_LRS'
  }
}

