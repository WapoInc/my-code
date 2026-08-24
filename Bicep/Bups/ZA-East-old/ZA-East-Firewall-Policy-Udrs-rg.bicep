targetScope = 'subscription'

@description('Existing resource group containing the ZA-East hub and spoke networks.')
param resourceGroupName string = 'za-east-southafricanorth'

@description('Azure region containing the existing ZA-East resources.')
param location string = 'southafricanorth'

@description('Name of the existing ZA-East hub virtual network.')
param hubVnetName string = 'za-east-${location}-vnet'

@description('Name of the existing NSG associated with the primary hub workload subnet.')
param hubWorkloadNsgName string = 'za-east-${location}-default-nsg'

@description('Name of the route-based VPN gateway in the hub VNet.')
param vpnGatewayName string = 'za-east-${location}-vpngw'

@description('Name of the VPN gateway public IP address.')
param vpnGatewayPublicIpName string = 'za-east-${location}-vpngw-pip'

@description('SKU of the VPN gateway.')
@allowed([
  'Basic'
  'VpnGw1'
  'VpnGw2'
  'VpnGw3'
  'VpnGw1AZ'
  'VpnGw2AZ'
  'VpnGw3AZ'
])
param vpnGatewaySku string = 'Basic'

@description('Administrator username for the Ubuntu test VMs.')
param vmAdminUsername string = 'rootadmin'

@secure()
@description('Administrator password for the Ubuntu test VMs.')
param vmAdminPassword string

@description('Size used by the Ubuntu test VMs.')
param vmSize string = 'Standard_B1ls'

@description('Controlled rollout stage for route-table associations.')
@allowed([
  'FirewallOnly'
  'GatewayAndTestSpoke'
  'AllSpokes'
  'Full'
])
param deploymentStage string = 'FirewallOnly'

@description('Approved on-premises CIDR prefixes learned through the VPN gateway.')
param approvedOnPremisesPrefixes array = []

@description('Send Internet-bound workload traffic to Azure Firewall, where policy permits HTTP and HTTPS egress.')
param enableInternetEgressRouting bool = true

@description('Name of the Log Analytics workspace created for Azure Firewall diagnostics.')
param logAnalyticsWorkspaceName string = 'AzFW-Basic-LA'

@description('Availability zones for the firewall and its public IP. Use an empty array for a regional deployment.')
param firewallZones array = [
  '1'
  '2'
  '3'
]

@description('Create the hub VNet when it is missing.')
param createHubVnet bool = false
param createHubWorkloadNsg bool = false
param createGatewaySubnet bool = false
param createVpnGatewayPublicIp bool = false
param createVpnGateway bool = false
param createFirewallSubnet bool = false
param createFirewallManagementSubnet bool = false
param createPingTestSubnet bool = false
param createHubVmSubnet bool = false
param createSpokeVnets array = [false, false, false]
param createSpokeSubnets array = [false, false, false]
param createHubToSpokePeerings array = [false, false, false]
param createSpokeToHubPeerings array = [false, false, false]

resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
}

module networkPrerequisites 'ZA-East-Network-Prerequisites.bicep' = {
  scope: resourceGroup
  params: {
    location: location
    hubVnetName: hubVnetName
    hubWorkloadNsgName: hubWorkloadNsgName
    vpnGatewayName: vpnGatewayName
    vpnGatewayPublicIpName: vpnGatewayPublicIpName
    vpnGatewaySku: vpnGatewaySku
    vmAdminUsername: vmAdminUsername
    vmAdminPassword: vmAdminPassword
    vmSize: vmSize
    createHubVnet: createHubVnet
    createHubWorkloadNsg: createHubWorkloadNsg
    createGatewaySubnet: createGatewaySubnet
    createVpnGatewayPublicIp: createVpnGatewayPublicIp
    createVpnGateway: createVpnGateway
    createFirewallSubnet: createFirewallSubnet
    createFirewallManagementSubnet: createFirewallManagementSubnet
    createPingTestSubnet: createPingTestSubnet
    createHubVmSubnet: createHubVmSubnet
    createSpokeVnets: createSpokeVnets
    createSpokeSubnets: createSpokeSubnets
    createHubToSpokePeerings: createHubToSpokePeerings
    createSpokeToHubPeerings: createSpokeToHubPeerings
  }
}

module firewallRouting 'ZA-East-Firewall-Policy-Udrs.bicep' = {
  scope: resourceGroup
  params: {
    location: location
    hubVnetName: hubVnetName
    hubWorkloadNsgName: hubWorkloadNsgName
    deploymentStage: deploymentStage
    approvedOnPremisesPrefixes: approvedOnPremisesPrefixes
    enableInternetEgressRouting: enableInternetEgressRouting
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    firewallZones: firewallZones
  }
  dependsOn: [
    networkPrerequisites
  ]
}

output resourceGroupName string = resourceGroup.name
output firewallName string = firewallRouting.outputs.firewallName
output firewallPolicyName string = firewallRouting.outputs.firewallPolicyName
output firewallPrivateIp string = firewallRouting.outputs.firewallPrivateIp
output firewallPublicIp string = firewallRouting.outputs.firewallPublicIp
output firewallManagementPublicIp string = firewallRouting.outputs.firewallManagementPublicIp
output logAnalyticsWorkspaceName string = firewallRouting.outputs.logAnalyticsWorkspaceName
output logAnalyticsWorkspaceId string = firewallRouting.outputs.logAnalyticsWorkspaceId
output spokeRouteTableIds array = firewallRouting.outputs.spokeRouteTableIds
output hubWorkloadRouteTableId string = firewallRouting.outputs.hubWorkloadRouteTableId
output gatewayReturnRouteTableId string = firewallRouting.outputs.gatewayReturnRouteTableId
output vpnGatewayId string = networkPrerequisites.outputs.vpnGatewayId
output vpnGatewayPublicIpId string = networkPrerequisites.outputs.vpnGatewayPublicIpId
output vmNames array = networkPrerequisites.outputs.vmNames
output vmPrivateIps array = networkPrerequisites.outputs.vmPrivateIps
output deploymentStage string = firewallRouting.outputs.deploymentStage
