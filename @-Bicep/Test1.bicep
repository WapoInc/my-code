


resource vmrstorage 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: 'vmr'
  location: 'southafricanorth'
  kind:'StorageV2'
  sku:{
    name:'Premium_LRS'   
  }
}
