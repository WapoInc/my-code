resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'bicep-poc2'
  location: 'southafricanorth'
}

param adminUsername string = 'azureuser'
param adminPassword string = 'P@ssw0rd1234!' // Ensure you use a secure password

resource vm 'Microsoft.Compute/virtualMachines@2021-07-01' = {
  name: 'ubuntuVM'
  location: rg.location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_DS1_v2'
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'UbuntuServer'
        sku: '18.04-LTS'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    osProfile: {
      computerName: 'ubuntuVM'
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2021-02-01' = {
  name: 'nic-ubuntuVM'
  location: rg.location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnet.id
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: 'vnet-ubuntuVM'
  location: rg.location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.13.0.0/23'
      ]
    }
    subnets: [
      {
        name: 'subnet1'
        properties: {
          addressPrefix: '10.13.0.0/24'
        }
      }
    ]
  }
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' existing = {
  parent: vnet
  name: 'subnet1'
}
```

This code will create a resource group named `bicep-poc2` and a Ubuntu VM in the South Africa North region with the VNet IP prefix set to `10.13.0.0/23`. If you have any further questions or need additional assistance, feel free to ask!
