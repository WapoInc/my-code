

param pubipname string = 'VM-Pub-IP3'
param mylocation string = resourceGroup().location

resource ip 'Microsoft.Network/publicIPAddresses@2021-02-01' = {
  name:pubipname
  location:mylocation
  sku:{
    name:'Standard'
  }
  properties:{
    publicIPAllocationMethod:'Static'
  }
}

