targetScope = 'resourceGroup'

@description('Azure region for the Log Analytics workspace.')
param location string = resourceGroup().location

@description('Name of the existing Azure Firewall.')
param firewallName string = 'AzFW'

@description('Name of the Log Analytics workspace.')
param logAnalyticsWorkspaceName string = 'law-mea-tech-community-day'

@description('Log retention period in days.')
@minValue(30)
param retentionInDays int = 30

@description('Optional resource tags.')
param tags object = {
  workload: 'MEA-Tech-Community-Day'
  environment: 'Lab'
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  tags: tags
  properties: {
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    retentionInDays: retentionInDays
    sku: {
      name: 'PerGB2018'
    }
  }
}

resource firewall 'Microsoft.Network/azureFirewalls@2024-05-01' existing = {
  name: firewallName
}

resource firewallNetworkRuleDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'send-network-rule-logs-to-log-analytics'
  scope: firewall
  properties: {
    logAnalyticsDestinationType: 'Dedicated'
    logs: [
      {
        category: 'AzureFirewallNetworkRule'
        enabled: true
      }
    ]
    workspaceId: logAnalyticsWorkspace.id
  }
}

output logAnalyticsWorkspaceName string = logAnalyticsWorkspace.name
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id
output firewallName string = firewall.name
output diagnosticSettingName string = firewallNetworkRuleDiagnostics.name
output networkRuleTableName string = 'AZFWNetworkRule'
output sampleQuery string = 'AZFWNetworkRule | where TimeGenerated > ago(1h) | order by TimeGenerated desc'
