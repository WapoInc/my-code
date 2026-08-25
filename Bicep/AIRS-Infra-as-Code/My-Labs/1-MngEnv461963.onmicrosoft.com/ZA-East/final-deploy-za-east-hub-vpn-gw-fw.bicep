targetScope = 'subscription'

@description('Name of the resource group to create or update.')
param resourceGroupName string = 'za-east-${location}'

@description('Azure region for the complete ZA-East deployment.')
param location string = 'southafricanorth'

@secure()
@description('Administrator password for the hub and spoke Ubuntu VMs.')
param adminPassword string

@allowed([
  'VpnGw1AZ'
  'VpnGw2AZ'
  'VpnGw3AZ'
  'VpnGw4AZ'
  'VpnGw5AZ'
])
@description('Zone-redundant VPN Gateway SKU.')
param vpnGatewaySku string = 'VpnGw1AZ'

@allowed([
  'Basic'
  'Standard'
  'Premium'
])
@description('Azure Firewall tier. A Firewall Policy and its rule collection group are always deployed and attached.')
param azureFirewallSku string = 'Standard'

@description('Enable BGP on the Azure VPN Gateway, FortiGate local network gateway, and S2S connection.')
param enableFortiGateBgp bool = true

@description('Create the FortiGate local network gateway and S2S connection.')
param createFortiGateLocalNetworkGateway bool = true

@description('Public IP address of the on-premises FortiGate VPN endpoint.')
param fortiGatePublicIp string = '156.155.28.158'

@description('On-premises CIDR prefixes reachable through the FortiGate VPN.')
param onPremisesAddressPrefixes array = [
  '192.168.2.0/24'
]

@description('BGP ASN used by the on-premises FortiGate.')
param fortiGateBgpAsn int = 65521

@description('BGP peer IP configured on the on-premises FortiGate.')
param fortiGateBgpPeerIp string = '66.66.66.66'

@description('BGP ASN used by the Azure VPN Gateway.')
param azureVpnBgpAsn int = 65515

var prefixedResourceGroupName = startsWith(toLower(resourceGroupName), 'za-east-') ? resourceGroupName : 'za-east-${resourceGroupName}'

resource resourceGroup 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: prefixedResourceGroupName
  location: location
  tags: {
    workload: 'ZA-East-Hub-Spoke'
    managedBy: 'Bicep'
  }
}

module zaEastHubVpnGatewayFirewall 'ZA-East-Hub-resources.bicep' = {
  name: 'final-za-east-hub-vpn-gw-fw'
  scope: resourceGroup
  params: {
    location: location
    adminPassword: adminPassword
    vpnGatewaySku: vpnGatewaySku
    azureFirewallSku: azureFirewallSku
    enableFortiGateBgp: enableFortiGateBgp
    createFortiGateLocalNetworkGateway: createFortiGateLocalNetworkGateway
    fortiGatePublicIp: fortiGatePublicIp
    onPremisesAddressPrefixes: onPremisesAddressPrefixes
    fortiGateBgpAsn: fortiGateBgpAsn
    fortiGateBgpPeerIp: fortiGateBgpPeerIp
    azureVpnBgpAsn: azureVpnBgpAsn
  }
}

output resourceGroupName string = resourceGroup.name
output vnetName string = zaEastHubVpnGatewayFirewall.outputs.vnetName
output vnetId string = zaEastHubVpnGatewayFirewall.outputs.vnetId
output vpnGatewayName string = zaEastHubVpnGatewayFirewall.outputs.vpnGatewayName
output vpnGatewayId string = zaEastHubVpnGatewayFirewall.outputs.vpnGatewayId
output vpnGatewaySku string = zaEastHubVpnGatewayFirewall.outputs.vpnGatewaySku
output gatewayPublicIpName string = zaEastHubVpnGatewayFirewall.outputs.gatewayPublicIpName
output azureFirewallName string = zaEastHubVpnGatewayFirewall.outputs.azureFirewallName
output azureFirewallSku string = zaEastHubVpnGatewayFirewall.outputs.azureFirewallSku
output azureFirewallPolicyName string = zaEastHubVpnGatewayFirewall.outputs.azureFirewallPolicyName
output azureFirewallRuleCollectionGroupName string = 'Allow-Private-Any-RCG'
output azureFirewallPrivateIp string = zaEastHubVpnGatewayFirewall.outputs.azureFirewallPrivateIp
output hubRouteTableId string = zaEastHubVpnGatewayFirewall.outputs.hubRouteTableId
output spokeRouteTableIds array = zaEastHubVpnGatewayFirewall.outputs.spokeRouteTableIds
output gatewayReturnRouteTableId string = zaEastHubVpnGatewayFirewall.outputs.gatewayReturnRouteTableId
output hubVmName string = zaEastHubVpnGatewayFirewall.outputs.vmName
output hubVmPrivateIp string = zaEastHubVpnGatewayFirewall.outputs.vmPrivateIp
output spokeVnetNames array = zaEastHubVpnGatewayFirewall.outputs.spokeVnetNames
output spokeVmNames array = zaEastHubVpnGatewayFirewall.outputs.spokeVmNames
output spokeVmPrivateIps array = zaEastHubVpnGatewayFirewall.outputs.spokeVmPrivateIps
