targetScope = 'subscription'

@description('Name of the resource group to create or update.')
param resourceGroupName string

@description('Azure region for all resources.')
param location string = 'southafricanorth'

@description('Name of the virtual network.')
param vnetName string

@description('Name of the subnet.')
param subnetName string

@description('Name of the Ubuntu virtual machine.')
@maxLength(64)
param vmName string

@description('Administrator username for the virtual machine.')
param adminUsername string

@description('Administrator password for the virtual machine.')
@secure()
param adminPassword string

@description('Size of the virtual machine.')
param vmSize string = 'Standard_B2s'

@description('Address space for the virtual network.')
param vnetCidr string = '10.0.0.0/16'

@description('Address prefix for the subnet.')
param subnetCidr string = '10.0.1.0/24'

@description('Create and attach a Standard public IP address.')
param createPublicIp bool = false

resource resourceGroup 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: resourceGroupName
  location: location
}

module vmResources 'CS-Ubuntu-VM.resources.bicep' = {
  scope: resourceGroup
  params: {
    location: location
    vnetName: vnetName
    subnetName: subnetName
    vmName: vmName
    adminUsername: adminUsername
    adminPassword: adminPassword
    vmSize: vmSize
    vnetCidr: vnetCidr
    subnetCidr: subnetCidr
    createPublicIp: createPublicIp
  }
}

output resourceGroupId string = resourceGroup.id
output vmId string = vmResources.outputs.vmId
output vmName string = vmResources.outputs.vmName
output adminUsername string = vmResources.outputs.adminUsername
output privateIpAddress string = vmResources.outputs.privateIpAddress
output publicIpAddress string = vmResources.outputs.publicIpAddress
