# Terraform calls resource provider APIs directly, so nothing shows up under
# Resource group > Settings > Deployments. These empty ARM deployments act as
# progress markers: each one is created only after the resources it depends on
# finish (via the resource IDs referenced in the template), so the Deployments blade shows how far the run has got.

locals {
  deployment_stages = {
    "tf-01-foundation" = [
      azurerm_resource_group.this,
      azurerm_log_analytics_workspace.this,
    ]
    "tf-02-networking" = [
      azurerm_subnet.onprem_hub,
      azurerm_subnet.onprem_subnet_4,
      azurerm_subnet.onprem_gateway,
      azurerm_subnet_route_table_association.azure_hub,
      azurerm_subnet_route_table_association.azure_gateway,
      azurerm_route.azure_hub_to_onprem_hub,
      azurerm_route.azure_hub_to_onprem_subnet_4,
      azurerm_route.azure_gateway_to_hub,
    ]
    "tf-03-firewall" = [
      azurerm_firewall.this,
      azurerm_firewall_policy_rule_collection_group.default,
      azurerm_monitor_diagnostic_setting.firewall,
    ]
    "tf-04-compute" = [
      azurerm_linux_virtual_machine.onprem_vm1,
      azurerm_linux_virtual_machine.onprem_vm2,
      azurerm_linux_virtual_machine.azure_vm1,
    ]
    "tf-05-vpn-gateways" = [
      azurerm_virtual_network_gateway.onprem,
      azurerm_virtual_network_gateway.azure,
    ]
    "tf-06-vpn-connections" = [
      azurerm_virtual_network_gateway_connection.onprem_to_azure,
      azurerm_virtual_network_gateway_connection.azure_to_onprem,
    ]
  }
}

resource "azurerm_resource_group_template_deployment" "stage" {
  for_each = local.deployment_stages

  name                = each.key
  resource_group_name = azurerm_resource_group.this.name
  deployment_mode     = "Incremental"

  template_content = jsonencode({
    "$schema"      = "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#"
    contentVersion = "1.0.0.0"
    metadata       = { stage = each.key, completedResources = [for r in each.value : r.id] }
    resources      = []
  })
}
