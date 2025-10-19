// Creating vars using Params
// Run in terminal:

// az account list
// az account set --subscription "Dele - Microsoft Azure Internal Consumption"
// az acoount set --subscription '@viresent - AIRS"

// az group create -g vmr-Bicep-ZAW --location SouthAfricaWest
// az deployment group create -f .\Bicep-Params-Var.bicep -g "vmr-Bicep-ZAW"





param mylocation string = resourceGroup().location
param stgname string = 'vmrstorage'

var mystgresource = '03${stgname}'
resource stg 'Microsoft.Storage/storageAccounts@2021-02-01' ={
  name: mystgresource
  location: mylocation
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
}
