data "azurerm_client_config" "current" {}

locals {
  boot_diagnostics_storage_name = "bootdiag${substr(md5("${data.azurerm_client_config.current.subscription_id}-${azurerm_resource_group.this.id}"), 0, 16)}"
}

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_storage_account" "boot_diagnostics" {
  name                            = local.boot_diagnostics_storage_name
  resource_group_name             = azurerm_resource_group.this.name
  location                        = azurerm_resource_group.this.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  account_kind                    = "StorageV2"
  allow_nested_items_to_be_public = false
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  tags                            = var.tags
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
