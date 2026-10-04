output "resource_group_name" {
  description = "Name of the deployed resource group."
  value       = azurerm_resource_group.this.name
}

output "boot_diagnostics_mode" {
  description = "Boot diagnostics storage mode used by the virtual machines."
  value       = "Azure-managed"
}

output "log_analytics_workspace_name" {
  description = "Log Analytics workspace receiving Azure Firewall logs."
  value       = azurerm_log_analytics_workspace.this.name
}

output "log_analytics_workspace_id" {
  description = "Resource ID of the Log Analytics workspace."
  value       = azurerm_log_analytics_workspace.this.id
}

output "firewall_diagnostic_setting_name" {
  description = "Name of the Azure Firewall diagnostic setting."
  value       = azurerm_monitor_diagnostic_setting.firewall.name
}

output "network_rule_table_name" {
  description = "Dedicated Log Analytics table for Azure Firewall network-rule logs."
  value       = "AZFWNetworkRule"
}

output "network_rule_sample_query" {
  description = "Sample KQL query for recent Azure Firewall network-rule logs."
  value       = "AZFWNetworkRule | where TimeGenerated > ago(1h) | order by TimeGenerated desc"
}

output "firewall_private_ip_address" {
  description = "Private IP address of Azure Firewall."
  value       = azurerm_firewall.this.ip_configuration[0].private_ip_address
}

output "firewall_public_ip_address" {
  description = "Public IP address of Azure Firewall."
  value       = azurerm_public_ip.firewall.ip_address
}

output "onprem_gateway_public_ip_address" {
  description = "Public IP address of the simulated on-premises VPN gateway."
  value       = azurerm_public_ip.onprem_gateway.ip_address
}

output "azure_gateway_public_ip_address" {
  description = "Public IP address of the Azure VPN gateway."
  value       = azurerm_public_ip.azure_gateway.ip_address
}

output "vpn_gateway_sku_name" {
  description = "SKU used by both VPN gateways."
  value       = var.vpn_gateway_sku
}
