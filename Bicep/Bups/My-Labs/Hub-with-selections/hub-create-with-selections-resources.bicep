// ============================================================
// Generic Lab - VNet + explicit Subnets + NSG + VM
// Resource-group scoped module (called by lab-vm-rg.bicep)
// ============================================================
// Each subnet's exact CIDR block is supplied explicitly (subnets
// can be different sizes) - the wrapper script works out
// non-overlapping blocks and passes them in via subnetCidrs.
// ============================================================

targetScope = 'resourceGroup'

// --- Core parameters ----------------------------------------
@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Name of the virtual network.')
param vnetName string = '${location}-vnet'

@description('Address space (CIDR) for the virtual network, e.g. 10.10.0.0/16.')
param vnetCidr string = '10.10.0.0/16'

@description('How many subnets to define (must match the entry counts of subnetNames and subnetCidrs).')
@minValue(1)
@maxValue(64)
param subnetCount int = 2

@description('Comma-separated list of exactly subnetCount explicit subnet names, e.g. "GatewaySubnet,Subnet-1,Subnet-2".')
param subnetNames string

@description('Comma-separated list of exactly subnetCount explicit, non-overlapping subnet CIDR blocks (one per subnet, independently sized), e.g. "10.80.0.0/26,10.80.0.64/27,10.80.0.96/27".')
param subnetCidrs string

@description('Name for the default NSG applied to every subnet.')
param nsgName string = '${location}-lab-nsg'

// --- VM parameters ------------------------------------------
@description('Which operating system to deploy on the VM.')
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

@description('Give the VM a public IP so you can reach it directly (useful for labs).')
param assignPublicIp bool = false

// --- Derived values -----------------------------------------
var isWindows = vmOs == 'WindowsServer2022'

var subnetNameList = split(subnetNames, ',')
var subnetCidrList = split(subnetCidrs, ',')

// GatewaySubnet is reserved for VPN/ExpressRoute gateways and cannot have an NSG attached.
var subnets = [
  for i in range(0, subnetCount): {
    name: subnetNameList[i]
    properties: union(
      {
        addressPrefix: subnetCidrList[i]
      },
      subnetNameList[i] == 'GatewaySubnet'
        ? {}
        : {
            networkSecurityGroup: {
              id: nsg.id
            }
          }
    )
  }
]

// GatewaySubnet is reserved for gateway resources - the VM NIC goes in the
// first subnet that isn't GatewaySubnet (falling back to subnets[0] if every
// subnet happens to be named GatewaySubnet).
var nonGatewaySubnets = filter(subnets, s => s.name != 'GatewaySubnet')
var vmSubnetName = length(nonGatewaySubnets) > 0 ? nonGatewaySubnets[0].name : subnets[0].name

// Management inbound rule differs by OS (RDP for Windows, SSH for Linux).
var mgmtRule = isWindows
  ? {
      name: 'Allow-RDP'
      properties: {
        priority: 1000
        direction: 'Inbound'
        access: 'Allow'
        protocol: 'Tcp'
        sourceAddressPrefix: '*'
        sourcePortRange: '*'
        destinationAddressPrefix: '*'
        destinationPortRange: '3389'
      }
    }
  : {
      name: 'Allow-SSH'
      properties: {
        priority: 1000
        direction: 'Inbound'
        access: 'Allow'
        protocol: 'Tcp'
        sourceAddressPrefix: '*'
        sourcePortRange: '*'
        destinationAddressPrefix: '*'
        destinationPortRange: '22'
      }
    }

// --- Default NSG --------------------------------------------
resource nsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      mgmtRule
    ]
  }
}

// --- Virtual network with auto-split subnets ----------------
resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetCidr
      ]
    }
    subnets: subnets
  }
}

// --- VM (placed in the first non-GatewaySubnet) --------------
module vmModule 'hub-vm-only.bicep' = {
  name: 'lab-vm-only'
  params: {
    location: location
    subnetId: '${vnet.id}/subnets/${vmSubnetName}'
    vmOs: vmOs
    vmName: vmName
    vmSize: vmSize
    adminUsername: adminUsername
    adminPassword: adminPassword
    assignPublicIp: assignPublicIp
  }
}

// --- Outputs ------------------------------------------------
output vnetName string = vnet.name
output vnetId string = vnet.id
output subnetNames array = [for (s, i) in subnets: subnets[i].name]
output subnetPrefixes array = [for (s, i) in subnets: subnets[i].properties.addressPrefix]
output nsgName string = nsg.name
output vmName string = vmModule.outputs.vmName
output vmNicName string = vmModule.outputs.vmNicName
output vmPrivateIp string = vmModule.outputs.vmPrivateIp
output vmPublicIp string = vmModule.outputs.vmPublicIp
