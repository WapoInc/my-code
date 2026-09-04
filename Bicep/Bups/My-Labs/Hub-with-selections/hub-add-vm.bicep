// ============================================================
// Generic Lab - Add a VM to an existing hub
// Resource-group scoped: attaches a new VM (+ NIC + optional
// public IP) to an existing VNet/subnet. Does not touch the
// existing VNet, subnets, or NSG.
// ============================================================
//
// az deployment group create \
//   -g my-existing-lab-rg \
//   -f hub-add-vm.bicep \
//   -p vnetName='southafricanorth-vnet' subnetName='Subnet-1' \
//      vmName='southafricanorth-lab-vm2' vmOs='Ubuntu2204' \
//      adminUsername='labadmin' adminPassword='P@ssw0rd123!'
//
// Normally you would run the deploy-hub-create-with-selections.sh
// wrapper instead of invoking this directly.
// ============================================================

targetScope = 'resourceGroup'

@description('Azure region for the new VM resources. Defaults to the resource group location.')
param location string = resourceGroup().location

@description('Name of the existing virtual network to attach the VM to.')
param vnetName string

@description('Name of the existing subnet (within that VNet) to place the VM NIC in.')
param subnetName string

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

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  name: vnetName
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' existing = {
  parent: vnet
  name: subnetName
}

module vmModule 'hub-vm-only.bicep' = {
  name: 'lab-vm-only'
  params: {
    location: location
    subnetId: subnet.id
    vmOs: vmOs
    vmName: vmName
    vmSize: vmSize
    adminUsername: adminUsername
    adminPassword: adminPassword
    assignPublicIp: assignPublicIp
  }
}

// --- Outputs ------------------------------------------------
output vmName string = vmModule.outputs.vmName
output vmNicName string = vmModule.outputs.vmNicName
output vmPrivateIp string = vmModule.outputs.vmPrivateIp
output vmPublicIp string = vmModule.outputs.vmPublicIp
