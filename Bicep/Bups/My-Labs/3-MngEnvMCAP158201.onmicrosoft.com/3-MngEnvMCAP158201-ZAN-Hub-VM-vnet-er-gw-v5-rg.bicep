// ============================================================
// SA-North-HUB - Resource Group + VNet + Subnets + ER GW + ER Connection + VM
// South Africa North  |  v5 - Bicep (subscription-scoped, creates the RG)
// ============================================================
// This is the hub orchestrator: it creates the resource group and
// deploys all hub resources (including the ExpressRoute connection)
// via the ZAN-Hub-VM-vnet-er-gw-v5-resources module.
//
// az deployment sub create \
//   -l southafricanorth \
//   -f 3-MngEnvMCAP158201-ZAN-Hub-VM-vnet-er-gw-v5-rg.bicep \
//   -p adminPassword='P@ssw0rd123!'
//
//
// NOTE: The ExpressRoute Gateway typically takes 20-45 minutes to provision;
// the ER connection is created automatically once the gateway is ready.
// ============================================================

targetScope = 'subscription'

@description('Name of the resource group to create.')
param resourceGroupName string = 'SA-North-region'

@description('Azure region for the resource group and all resources.')
param location string = 'southafricanorth'

@secure()
param adminPassword string

@description('Create the ExpressRoute connection after the gateway is ready.')
param deployErConnection bool = true

@description('Name of the existing ExpressRoute circuit to connect to.')
param circuitName string = 'ER-LIT-ZAN'

@description('Resource group that contains the ExpressRoute circuit.')
param circuitResourceGroup string = 'ER-LTSA-rg'

// --- Resource Group -----------------------------------------
resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: resourceGroupName
  location: location
}

// --- Hub resources (VNet, subnets, NSG, ER GW, ER Connection, VM) ----
module resources '3-MngEnvMCAP158201-ZAN-Hub-VM-vnet-er-gw-v5-resources.bicep' = {
  name: 'sa-north-hub'
  scope: rg
  params: {
    location: location
    adminPassword: adminPassword
    deployErConnection: deployErConnection
    circuitName: circuitName
    circuitResourceGroup: circuitResourceGroup
  }
}

// --- Outputs ------------------------------------------------
output resourceGroupName string = rg.name
output vnetId string = resources.outputs.vnetId
output vmPrivateIp string = resources.outputs.vmPrivateIp
output erGatewayId string = resources.outputs.erGatewayId
output erConnectionId string = resources.outputs.erConnectionId
