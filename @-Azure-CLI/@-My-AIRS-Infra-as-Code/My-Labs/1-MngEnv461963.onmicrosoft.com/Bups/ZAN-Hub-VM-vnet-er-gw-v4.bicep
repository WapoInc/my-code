// ============================================================
// Deploy SA-North-HUB - Resource Group + VNet + Subnets + ER GW + VM
// South Africa North  |  v4 - Bicep (subscription-scoped, creates the RG)
// ============================================================
// Deploy (no pre-created RG needed):
//   az deployment sub create \
//     -l southafricanorth \
//     -f ZAN-Hub-VM-vnet-er-gw-v4.bicep \
//     -p adminPassword='P@ssw0rd123!'
//
// NOTE: The ExpressRoute Gateway typically takes 20-45 minutes to provision.
// ============================================================

targetScope = 'subscription'

@description('Name of the resource group to create.')
param resourceGroupName string = 'SA-North-region-bicep'

@description('Azure region for the resource group and all resources.')
param location string = 'southafricanorth'

@secure()
param adminPassword string

// --- Resource Group -----------------------------------------
resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: resourceGroupName
  location: location
}

// --- Hub resources (VNet, subnets, NSG, ER GW, VM) ----------
module hub 'ZAN-Hub-VM-vnet-er-gw-v4-resources.bicep' = {
  name: 'sa-north-hub'
  scope: rg
  params: {
    location: location
    adminPassword: adminPassword
  }
}

// --- Outputs ------------------------------------------------
output resourceGroupName string = rg.name
output vnetId string = hub.outputs.vnetId
output vmPrivateIp string = hub.outputs.vmPrivateIp
output erGatewayId string = hub.outputs.erGatewayId
