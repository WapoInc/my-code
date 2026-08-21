// ============================================================
// Generic Lab - VM + NIC + optional public IP
// Resource-group scoped module: creates a VM attached to a given
// subnet ID. Shared by both the new-hub flow (rg + resources
// bicep) and the add-VM-to-existing-hub flow (hub-add-vm.bicep).
// ============================================================

targetScope = 'resourceGroup'

@description('Azure region for the VM resources.')
param location string = resourceGroup().location

@description('Resource ID of the subnet to place the VM NIC in.')
param subnetId string

@description('Which operating system to deploy on the VM.')
@allowed([
  'Ubuntu2204'
  'WindowsServer2022'
])
param vmOs string = 'Ubuntu2204'

@description('Name of the virtual machine.')
param vmName string

@description('VM size (SKU).')
param vmSize string = 'Standard_B2s'

@description('Admin username for the VM.')
param adminUsername string = 'labadmin'

@secure()
@description('Admin password for the VM.')
param adminPassword string

@description('Give the VM a public IP so you can reach it directly (useful for labs).')
param assignPublicIp bool = false

var isWindows = vmOs == 'WindowsServer2022'

// Windows computer name is limited to 15 characters.
var computerName = isWindows ? substring(vmName, 0, min(length(vmName), 15)) : vmName

var vmNicName = '${vmName}-nic'
var vmPipName = '${vmName}-pip'

// OS image reference.
var imageReference = isWindows
  ? {
      publisher: 'MicrosoftWindowsServer'
      offer: 'WindowsServer'
      sku: '2022-datacenter-azure-edition'
      version: 'latest'
    }
  : {
      publisher: 'Canonical'
      offer: '0001-com-ubuntu-server-jammy'
      sku: '22_04-lts-gen2'
      version: 'latest'
    }

// --- Optional public IP for the VM --------------------------
resource pip 'Microsoft.Network/publicIPAddresses@2023-11-01' = if (assignPublicIp) {
  name: vmPipName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// --- VM NIC ----------------------------------------------------
resource nic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: vmNicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetId
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: assignPublicIp
            ? {
                id: pip.id
              }
            : null
        }
      }
    ]
  }
}

// --- Virtual machine ----------------------------------------
resource vm 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: union(
      {
        computerName: computerName
        adminUsername: adminUsername
        adminPassword: adminPassword
      },
      isWindows
        ? {}
        : {
            linuxConfiguration: {
              disablePasswordAuthentication: false
            }
          }
    )
    storageProfile: {
      imageReference: imageReference
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
    // Managed boot diagnostics - Azure handles the storage, no account needed.
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}

// --- Outputs ------------------------------------------------
output vmName string = vm.name
output vmNicName string = nic.name
output vmPrivateIp string = nic.properties.ipConfigurations[0].properties.privateIPAddress
// pip only exists when assignPublicIp is true; the ternary guards the access.
#disable-next-line BCP318
output vmPublicIp string = assignPublicIp ? pip.properties.ipAddress : ''
