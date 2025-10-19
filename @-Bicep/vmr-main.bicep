

param location string = 'southafricanorth' 
param StorageAccountName string = 'vmr001'

resource storage 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: StorageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind:'StorageV2' 
  
}
