using './ZA-East-Firewall-Policy-Udrs-rg.bicep'

param resourceGroupName = 'za-east-southafricanorth'
param location = 'southafricanorth'
param deploymentStage = 'Full'
param approvedOnPremisesPrefixes = [
  '192.168.20.0/24'
  '66.66.66.66/32'
  '192.168.2.0/24'
  '192.168.10.0/24'
  '10.25.0.0/24'
  '10.24.0.0/24'
]
param enableInternetEgressRouting = true
param logAnalyticsWorkspaceName = 'AzFW-Basic-LA'
param firewallZones = []
