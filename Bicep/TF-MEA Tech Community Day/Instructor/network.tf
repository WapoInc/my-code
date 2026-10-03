resource "azurerm_virtual_network" "onprem" {
  name                = "onprem-vnet"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  address_space = [
    "192.168.0.0/22",
    "192.168.4.0/22",
  ]
  tags = var.tags
}

resource "azurerm_subnet" "onprem_hub" {
  name                 = "onprem-hub"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.onprem.name
  address_prefixes     = ["192.168.1.0/24"]
}

resource "azurerm_subnet" "onprem_subnet_4" {
  name                 = "Subnet-4"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.onprem.name
  address_prefixes     = ["192.168.4.0/24"]
}

resource "azurerm_subnet" "onprem_gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.onprem.name
  address_prefixes     = ["192.168.0.0/27"]
}

resource "azurerm_virtual_network" "azure" {
  name                = "azure-vnet"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  address_space       = ["10.70.0.0/22"]
  tags                = var.tags
}

resource "azurerm_subnet" "azure_firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.azure.name
  address_prefixes     = ["10.70.3.0/26"]
}

resource "azurerm_public_ip" "firewall" {
  name                = "AzFW-Pub-IP"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  allocation_method   = "Static"
  sku                 = "Standard"
  ip_version          = "IPv4"
  tags                = var.tags
}

resource "azurerm_firewall_policy" "this" {
  name                     = "AzFW-Policy-01"
  resource_group_name      = azurerm_resource_group.this.name
  location                 = azurerm_resource_group.this.location
  sku                      = "Standard"
  threat_intelligence_mode = "Alert"
  tags                     = var.tags
}

resource "azurerm_firewall_policy_rule_collection_group" "default" {
  name               = "DefaultNetworkRuleCollectionGroup"
  firewall_policy_id = azurerm_firewall_policy.this.id
  priority           = 200

  network_rule_collection {
    name     = "NetworkRuleCollection"
    priority = 100
    action   = "Allow"

    rule {
      name                  = "Allow-Onprem-Hub-to-Azure"
      protocols             = ["TCP", "UDP", "ICMP"]
      source_addresses      = ["192.168.1.0/24"]
      destination_addresses = ["10.70.1.0/24"]
      destination_ports     = ["*"]
    }

    rule {
      name                  = "Allow-Onprem-Subnet4-to-Azure"
      protocols             = ["TCP", "UDP", "ICMP"]
      source_addresses      = ["192.168.4.0/24"]
      destination_addresses = ["10.70.1.0/24"]
      destination_ports     = ["*"]
    }

    rule {
      name             = "Allow-Azure-to-Onprem"
      protocols        = ["TCP", "UDP", "ICMP"]
      source_addresses = ["10.70.1.0/24"]
      destination_addresses = [
        "192.168.1.0/24",
        "192.168.4.0/24",
      ]
      destination_ports = ["*"]
    }
  }
}

resource "azurerm_firewall" "this" {
  name                = "AzFW"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  firewall_policy_id  = azurerm_firewall_policy.this.id
  threat_intel_mode   = "Alert"
  tags                = var.tags

  ip_configuration {
    name                 = "azureFirewallIpConfiguration"
    subnet_id            = azurerm_subnet.azure_firewall.id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }

  depends_on = [azurerm_firewall_policy_rule_collection_group.default]
}

resource "azurerm_monitor_diagnostic_setting" "firewall" {
  name                           = "send-network-rule-logs-to-log-analytics"
  target_resource_id             = azurerm_firewall.this.id
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.this.id
  log_analytics_destination_type = "Dedicated"

  enabled_log {
    category = "AzureFirewallNetworkRule"
  }
}

resource "azurerm_route_table" "azure_hub" {
  name                          = "azure-subnet-rt"
  resource_group_name           = azurerm_resource_group.this.name
  location                      = azurerm_resource_group.this.location
  bgp_route_propagation_enabled = true
  tags                          = var.tags
}

resource "azurerm_route" "azure_hub_to_onprem_hub" {
  name                   = "route-to-onprem-192-168-1-0"
  resource_group_name    = azurerm_resource_group.this.name
  route_table_name       = azurerm_route_table.azure_hub.name
  address_prefix         = "192.168.1.0/24"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.this.ip_configuration[0].private_ip_address
}

resource "azurerm_route" "azure_hub_to_onprem_subnet_4" {
  name                   = "route-to-onprem-192-168-4-0"
  resource_group_name    = azurerm_resource_group.this.name
  route_table_name       = azurerm_route_table.azure_hub.name
  address_prefix         = "192.168.4.0/24"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.this.ip_configuration[0].private_ip_address
}

resource "azurerm_route_table" "azure_gateway" {
  name                          = "azure-gateway-subnet-rt"
  resource_group_name           = azurerm_resource_group.this.name
  location                      = azurerm_resource_group.this.location
  bgp_route_propagation_enabled = true
  tags                          = var.tags
}

resource "azurerm_route" "azure_gateway_to_hub" {
  name                   = "route-to-hub-subnet"
  resource_group_name    = azurerm_resource_group.this.name
  route_table_name       = azurerm_route_table.azure_gateway.name
  address_prefix         = "10.70.1.0/24"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.this.ip_configuration[0].private_ip_address
}

resource "azurerm_subnet" "azure_hub" {
  name                 = "azure-hub"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.azure.name
  address_prefixes     = ["10.70.1.0/24"]
}

resource "azurerm_subnet_route_table_association" "azure_hub" {
  subnet_id      = azurerm_subnet.azure_hub.id
  route_table_id = azurerm_route_table.azure_hub.id
}

resource "azurerm_subnet" "azure_gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.azure.name
  address_prefixes     = ["10.70.0.0/27"]
}

resource "azurerm_subnet_route_table_association" "azure_gateway" {
  subnet_id      = azurerm_subnet.azure_gateway.id
  route_table_id = azurerm_route_table.azure_gateway.id
}

resource "azurerm_public_ip" "onprem_gateway" {
  name                = "onprem-gateway-pip-zr"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  allocation_method   = "Static"
  sku                 = "Standard"
  ip_version          = "IPv4"
  zones               = ["1", "2", "3"]
  tags                = var.tags
}

resource "azurerm_public_ip" "azure_gateway" {
  name                = "azure-gateway-pip-zr"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  allocation_method   = "Static"
  sku                 = "Standard"
  ip_version          = "IPv4"
  zones               = ["1", "2", "3"]
  tags                = var.tags
}

resource "azurerm_virtual_network_gateway" "onprem" {
  name                = "onprem-gateway"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  type                = "Vpn"
  vpn_type            = "RouteBased"
  active_active       = false
  bgp_enabled         = false
  sku                 = var.vpn_gateway_sku
  generation          = "Generation1"
  tags                = var.tags

  ip_configuration {
    name                          = "gwipconfig"
    public_ip_address_id          = azurerm_public_ip.onprem_gateway.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.onprem_gateway.id
  }
}

resource "azurerm_virtual_network_gateway" "azure" {
  name                = "azure-gateway"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  type                = "Vpn"
  vpn_type            = "RouteBased"
  active_active       = false
  bgp_enabled         = false
  sku                 = var.vpn_gateway_sku
  generation          = "Generation1"
  tags                = var.tags

  ip_configuration {
    name                          = "gwipconfig"
    public_ip_address_id          = azurerm_public_ip.azure_gateway.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.azure_gateway.id
  }

  depends_on = [azurerm_subnet_route_table_association.azure_gateway]
}

resource "azurerm_local_network_gateway" "azure" {
  name                = "azure-local-gateway"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  gateway_address     = azurerm_public_ip.azure_gateway.ip_address
  address_space       = ["10.70.0.0/22"]
  tags                = var.tags

  depends_on = [azurerm_virtual_network_gateway.azure]
}

resource "azurerm_local_network_gateway" "onprem" {
  name                = "onprem-local-gateway"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  gateway_address     = azurerm_public_ip.onprem_gateway.ip_address
  address_space = [
    "192.168.0.0/22",
    "192.168.4.0/22",
  ]
  tags = var.tags

  depends_on = [azurerm_virtual_network_gateway.onprem]
}

resource "azurerm_virtual_network_gateway_connection" "onprem_to_azure" {
  name                       = "onprem-to-azure"
  resource_group_name        = azurerm_resource_group.this.name
  location                   = azurerm_resource_group.this.location
  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.onprem.id
  local_network_gateway_id   = azurerm_local_network_gateway.azure.id
  shared_key                 = var.vpn_shared_key
  tags                       = var.tags
}

resource "azurerm_virtual_network_gateway_connection" "azure_to_onprem" {
  name                       = "azure-to-onprem"
  resource_group_name        = azurerm_resource_group.this.name
  location                   = azurerm_resource_group.this.location
  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.azure.id
  local_network_gateway_id   = azurerm_local_network_gateway.onprem.id
  shared_key                 = var.vpn_shared_key
  tags                       = var.tags
}
