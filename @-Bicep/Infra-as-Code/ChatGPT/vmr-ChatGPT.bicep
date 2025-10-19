param adminUsername string = 'vmradmin'
param adminPassword securestring = 'P@ssw0rd123!'

resource publicIp 'Microsoft.Network/publicIPAddresses@2021-03-01' = {
  name: 'vmr-public-ip'
  location: 'southafricanorth'
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2021-03-01' = {
  name: 'vmr-nic'
  location: 'southafricanorth'
  properties: {
    ipConfigurations: [
      {
        name: 'vmr-ipconfig'
        properties: {
          subnet: {
            id: subnetRef.id
          }
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2021-03-01' = {
  name: 'vmr-VM1'
  location: 'southafricanorth'
  dependsOn: [
    nic
  ]
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B2s'
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2019-Datacenter'
        version: 'latest'
      }
      osDisk: {
        name: 'vmr-osdisk'
        caching: 'ReadWrite'
        createOption: 'FromImage'
        diskSizeGB: 128
    }
  }
  osProfile: {
    computerName: 'vmr-VM1'
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

resource subnetRef 'Microsoft.Network/virtualNetworks/subnets@2021-03-01' = {
  name: 'default'
  properties: {
    addressPrefix: '10.0.0.0/16'
  }
}
