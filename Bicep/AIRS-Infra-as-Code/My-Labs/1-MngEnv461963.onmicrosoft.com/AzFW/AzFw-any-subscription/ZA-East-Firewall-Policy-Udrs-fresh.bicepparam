using './ZA-East-Firewall-Policy-Udrs-rg.bicep'

param resourceGroupName = 'za-east-southafricanorth'
param location = 'southafricanorth'
param hubVnetName = 'za-east-southafricanorth-vnet'
param hubWorkloadNsgName = 'za-east-southafricanorth-default-nsg'
param vpnGatewayName = 'za-east-southafricanorth-vpngw'
param vpnGatewayPublicIpName = 'za-east-southafricanorth-vpngw-pip'
param deploymentStage = 'FirewallOnly'
param approvedOnPremisesPrefixes = []
param enableInternetEgressRouting = true
param logAnalyticsWorkspaceName = 'AzFW-Basic-LA'
param firewallZones = []

param createHubVnet = true
param createHubWorkloadNsg = true
param createGatewaySubnet = true
param createVpnGatewayPublicIp = true
param createVpnGateway = true
param createFirewallSubnet = true
param createFirewallManagementSubnet = true
param createHubWorkloadSubnet = true
param createPingTestSubnet = true
param createSpokeVnets = [true, true, true]
param createSpokeSubnets = [true, true, true]
param createHubToSpokePeerings = [true, true, true]
param createSpokeToHubPeerings = [true, true, true]
