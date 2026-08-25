// ============================================================
// ZA-East-HUB - Resource Group + VNet + Subnets + optional VPN Gateway + VM
// South Africa North  |  v5 - Bicep (subscription-scoped, creates the RG)
// ============================================================
// This is the hub orchestrator: it creates the resource group and
// deploys all hub resources, including the optional VPN gateway,
// via the ZA-East-Hub-resources module.
//
// az deployment sub create \
//   -l southafricanorth \
//   -f ZA-East-Hub-resources-rg.bicep \
//   -p adminPassword='P@ssw0rd123!'
//
//


// NOTE: A VPN gateway typically takes 20-45 minutes to provision.
// ============================================================

targetScope = 'subscription'

@description('Name of the resource group to create.')
param resourceGroupName string = 'za-east-${location}'

var prefixedResourceGroupName = startsWith(toLower(resourceGroupName), 'za-east-') ? resourceGroupName : 'za-east-${resourceGroupName}'

@description('Azure region for the resource group and all resources.')
param location string = 'southafricanorth'

@secure()
param adminPassword string

@allowed([
  'None'
  'VpnGw1AZ'
  'VpnGw2AZ'
  'VpnGw3AZ'
  'VpnGw4AZ'
  'VpnGw5AZ'
])
@description('VPN gateway SKU to deploy. Select None to skip the VPN gateway and its public IP.')
param vpnGatewaySku string = 'None'

@allowed([
  'None'
  'Basic'
  'Standard'
  'Premium'
])
@description('Azure Firewall tier to deploy. Select None to skip Azure Firewall.')
param azureFirewallSku string = 'None'

@description('Enable BGP on the Azure VPN gateway, local network gateway, and connection.')
param enableFortiGateBgp bool = true

@description('Create the FortiGate local network gateway.')
param createFortiGateLocalNetworkGateway bool = false

@description('BGP ASN used by the on-premises FortiGate.')
param fortiGateBgpAsn int = 65521

@description('On-premises CIDR prefixes reachable through the FortiGate VPN.')
param onPremisesAddressPrefixes array = [
  '192.168.2.0/24'
]

@description('BGP peer IP address configured on the on-premises FortiGate.')
param fortiGateBgpPeerIp string = '66.66.66.66'

@description('BGP ASN used by the Azure VPN gateway.')
param azureVpnBgpAsn int = 65515

// --- Resource Group -----------------------------------------
resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: prefixedResourceGroupName
  location: location
  tags: {
    'NB!!!': 'vmr'
  }
}

// --- Hub resources (VNet, subnets, NSG, optional VPN gateway, VM) ----
module resources 'ZA-East-Hub-resources.bicep' = {
  name: 'za-east-hub'
  scope: rg
  params: {
    location: location
    adminPassword: adminPassword
    vpnGatewaySku: vpnGatewaySku
    azureFirewallSku: azureFirewallSku
    enableFortiGateBgp: enableFortiGateBgp
    createFortiGateLocalNetworkGateway: createFortiGateLocalNetworkGateway
    fortiGateBgpAsn: fortiGateBgpAsn
    onPremisesAddressPrefixes: onPremisesAddressPrefixes
    fortiGateBgpPeerIp: fortiGateBgpPeerIp
    azureVpnBgpAsn: azureVpnBgpAsn
  }
}

// --- Outputs ------------------------------------------------
output resourceGroupName string = rg.name
output networkSecurityGroupName string = resources.outputs.networkSecurityGroupName
output gatewayPublicIpName string = resources.outputs.gatewayPublicIpName
output vnetName string = resources.outputs.vnetName
output vnetId string = resources.outputs.vnetId
output vmName string = resources.outputs.vmName
output vmNicName string = resources.outputs.vmNicName
output vmPrivateIp string = resources.outputs.vmPrivateIp
output vpnGatewaySku string = resources.outputs.vpnGatewaySku
output vpnGatewayName string = resources.outputs.vpnGatewayName
output vpnGatewayId string = resources.outputs.vpnGatewayId
output azureFirewallSku string = resources.outputs.azureFirewallSku
output azureFirewallName string = resources.outputs.azureFirewallName
output azureFirewallPolicyName string = resources.outputs.azureFirewallPolicyName
output azureFirewallPrivateIp string = resources.outputs.azureFirewallPrivateIp
output hubRouteTableId string = resources.outputs.hubRouteTableId
output spokeRouteTableIds array = resources.outputs.spokeRouteTableIds
output gatewayReturnRouteTableId string = resources.outputs.gatewayReturnRouteTableId
