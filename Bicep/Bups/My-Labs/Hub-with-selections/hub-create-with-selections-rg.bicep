// ============================================================
// Generic Lab - Resource Group orchestrator
// Subscription-scoped: creates the resource group, then deploys
// the VNet / subnets / NSG / VM via the lab-vm-resources module.
// ============================================================
//
// az deployment sub create \
//   -l southafricanorth \
//   -f hub-create-with-selections-rg.bicep \
//   -p resourceGroupName='my-lab-rg' vnetCidr='10.20.0.0/16' \
//      subnetCount=3 subnetNames='GatewaySubnet,Subnet-1,Subnet-2' \
//      subnetCidrs='10.20.0.0/26,10.20.0.64/27,10.20.0.96/27' \
//      vmOs='Ubuntu2204' adminUsername='labadmin' adminPassword='P@ssw0rd123!'
//
// Normally you would run the deploy-lab-vm.sh wrapper instead of
// invoking this directly - the deploy-hub-create-with-selections.sh wrapper prompts for every value.
// ============================================================

targetScope = 'subscription'

@description('Name of the resource group to create.')
param resourceGroupName string = '${location}-lab-rg'

@description('Azure region for the resource group and all resources.')
param location string = 'southafricanorth'

@description('Address space (CIDR) for the virtual network.')
param vnetCidr string = '10.10.0.0/16'

@description('How many subnets to define (must match the entry counts of subnetNames and subnetCidrs).')
param subnetCount int = 2

@description('Comma-separated list of exactly subnetCount explicit subnet names, e.g. "GatewaySubnet,Subnet-1,Subnet-2".')
param subnetNames string

@description('Comma-separated list of exactly subnetCount explicit, non-overlapping subnet CIDR blocks (one per subnet, independently sized), e.g. "10.80.0.0/26,10.80.0.64/27,10.80.0.96/27".')
param subnetCidrs string

@description('Operating system for the VM.')
@allowed([
  'Ubuntu2204'
  'WindowsServer2022'
])
param vmOs string = 'Ubuntu2204'

@description('Name of the virtual machine.')
param vmName string = '${location}-lab-vm'

@description('VM size (SKU).')
param vmSize string = 'Standard_B2s'

@description('Admin username for the VM.')
param adminUsername string = 'labadmin'

@secure()
@description('Admin password for the VM.')
param adminPassword string

@description('Give the VM a public IP so you can reach it directly.')
param assignPublicIp bool = false

// --- Resource Group -----------------------------------------
resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: resourceGroupName
  location: location
  tags: {
    purpose: 'lab'
  }
}

// --- Lab resources ------------------------------------------
module resources 'hub-create-with-selections-resources.bicep' = {
  name: 'lab-vm-resources'
  scope: rg
  params: {
    location: location
    vnetCidr: vnetCidr
    subnetCount: subnetCount
    subnetNames: subnetNames
    subnetCidrs: subnetCidrs
    vmOs: vmOs
    vmName: vmName
    vmSize: vmSize
    adminUsername: adminUsername
    adminPassword: adminPassword
    assignPublicIp: assignPublicIp
  }
}

// --- Outputs ------------------------------------------------
output resourceGroupName string = rg.name
output vnetName string = resources.outputs.vnetName
output subnetNames array = resources.outputs.subnetNames
output subnetPrefixes array = resources.outputs.subnetPrefixes
output vmName string = resources.outputs.vmName
output vmPrivateIp string = resources.outputs.vmPrivateIp
output vmPublicIp string = resources.outputs.vmPublicIp
