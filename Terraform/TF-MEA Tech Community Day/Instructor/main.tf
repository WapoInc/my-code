resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_log_analytics_workspace" "this" {
  name                            = var.log_analytics_workspace_name
  resource_group_name             = azurerm_resource_group.this.name
  location                        = azurerm_resource_group.this.location
  sku                             = "PerGB2018"
  retention_in_days               = var.log_analytics_retention_in_days
  allow_resource_only_permissions = true
  tags                            = var.tags
}
