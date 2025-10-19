param virtualMachines_Ping_Test_name string = 'Ping-Test2'
param disks_Ping_Test_OsDisk_1_a88aa44d2ca8438fb1bbab2e99c7fb9a_externalid string = 'OS_Disk2'
param networkInterfaces_ping_test476_externalid string = 'ping-test2'

resource virtualMachines_Ping_Test_name_resource 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: virtualMachines_Ping_Test_name
  location: 'southafricanorth'
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B1s'
    }
    storageProfile: {
      imageReference: {
        publisher: 'canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        osType: 'Linux'
        name: '${virtualMachines_Ping_Test_name}_OsDisk_1_a88aa44d2ca8438fb1bbab2e99c7fb9a'
        createOption: 'FromImage'
        caching: 'ReadWrite'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
          id: disks_Ping_Test_OsDisk_1_a88aa44d2ca8438fb1bbab2e99c7fb9a_externalid
        }
        deleteOption: 'Delete'
        diskSizeGB: 30
      }
      dataDisks: []
      diskControllerType: 'SCSI'
    }
    osProfile: {
      computerName: virtualMachines_Ping_Test_name
      adminUsername: 'rootadmin'
      linuxConfiguration: {
        disablePasswordAuthentication: false
        provisionVMAgent: true
        patchSettings: {
          patchMode: 'AutomaticByPlatform'
          automaticByPlatformSettings: {
            bypassPlatformSafetyChecksOnUserSchedule: true
          }
          assessmentMode: 'AutomaticByPlatform'
        }
        enableVMAgentPlatformUpdates: false
      }
      secrets: []
      allowExtensionOperations: true
      requireGuestProvisionSignal: true
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterfaces_ping_test476_externalid
          properties: {
            deleteOption: 'Detach'
          }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}

resource virtualMachines_Ping_Test_name_AzureNetworkWatcherExtension 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = {
  parent: virtualMachines_Ping_Test_name_resource
  name: 'AzureNetworkWatcherExtension'
  location: 'southafricanorth'
  properties: {
    autoUpgradeMinorVersion: true
    publisher: 'Microsoft.Azure.NetworkWatcher'
    type: 'NetworkWatcherAgentLinux'
    typeHandlerVersion: '1.4'
  }
}
