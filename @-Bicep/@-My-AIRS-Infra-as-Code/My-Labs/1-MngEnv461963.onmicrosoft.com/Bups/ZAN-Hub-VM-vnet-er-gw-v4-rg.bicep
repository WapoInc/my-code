// ============================================================
// SA-North-HUB - Resource Group + VNet + Subnets + ER GW + VM
// South Africa North  |  v4 - Bicep (subscription-scoped, creates the RG)
// ============================================================
// This is the hub orchestrator: it creates the resource group and
// deploys all hub resources via the ZAN-Hub-VM-vnet-er-gw-v4-resources
// module.
//
// Deploy (no pre-created RG needed):
// az deployment sub create \
//     -l southafricanorth \
//     -f ZAN-Hub-VM-vnet-er-gw-v4-rg.bicep \
//     -p adminPassword='P@ssw0rd123!'
//
// NOTE: The ExpressRoute Gateway typically takes 20-45 minutes to provision.
// ============================================================

targetScope = 'subscription'

@description('Name of the resource group to create.')
param resourceGroupName string = 'SA-North-region'

@description('Azure region for the resource group and all resources.')
param location string = 'southafricanorth'

@secure()
param adminPassword string

@description('Deploy the ExpressRoute connection to the circuit after the gateway is created.')
param deployErConnection bool = false

@description('Name of the existing ExpressRoute circuit to connect to.')
param circuitName string = 'ER-LIT-ZAN'

@description('Resource group that contains the ExpressRoute circuit.')
param circuitResourceGroup string = 'ER-LTSA-rg'

// --- Resource Group -----------------------------------------
resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: resourceGroupName
  location: location
}

// --- Hub resources (VNet, subnets, NSG, ER GW, VM) ----------
module resources 'ZAN-Hub-VM-vnet-er-gw-v4-resources.bicep' = {
  name: 'sa-north-hub'
  scope: rg
  params: {
    location: location
    adminPassword: adminPassword
  }
}

// --- ExpressRoute connection (optional; after gateway is ready) ----
module erConnection 'ZAN-Hub-ER-Connection-v4.bicep' = if (deployErConnection) {
  name: 'sa-north-er-connection'
  scope: rg
  params: {
    location: location
    circuitName: circuitName
    circuitResourceGroup: circuitResourceGroup
  }
  dependsOn: [
    resources
  ]
}

// --- Outputs ------------------------------------------------
output resourceGroupName string = rg.name
output vnetId string = resources.outputs.vnetId
output vmPrivateIp string = resources.outputs.vmPrivateIp
output erGatewayId string = resources.outputs.erGatewayId
output createdResources array = resources.outputs.createdResources
