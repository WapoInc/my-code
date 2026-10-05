variable "subscription_id" {
  type        = string
  description = "Azure subscription ID. When null, the AzureRM provider uses ARM_SUBSCRIPTION_ID."
  default     = null
  nullable    = true
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group that contains the lab resources."
  default     = "MEA-Instructor"
}

variable "location" {
  type        = string
  description = "Azure region for all resources."
  default     = "southafricanorth"
}

variable "admin_username" {
  type        = string
  description = "Administrator username for the Linux virtual machines."
  default     = "adminazure"
}

variable "admin_password" {
  type        = string
  description = "Administrator password for the Linux virtual machines."
  sensitive   = true

  validation {
    condition     = length(var.admin_password) >= 12
    error_message = "admin_password must be at least 12 characters."
  }

  validation {
    condition = length(compact([
      length(regexall("[a-z]", var.admin_password)) > 0 ? "lowercase" : "",
      length(regexall("[A-Z]", var.admin_password)) > 0 ? "uppercase" : "",
      length(regexall("[0-9]", var.admin_password)) > 0 ? "digit" : "",
      length(regexall("[^0-9A-Za-z_]", var.admin_password)) > 0 ? "special" : "",
    ])) >= 3
    error_message = "admin_password must contain at least three of: lowercase letters, uppercase letters, digits, and special characters other than underscore."
  }
}

variable "vpn_shared_key" {
  type        = string
  description = "Pre-shared key used by both VPN connections."
  sensitive   = true
  default     = "S2SPSK123!"

  validation {
    condition     = length(var.vpn_shared_key) > 0
    error_message = "vpn_shared_key cannot be empty."
  }
}

variable "vpn_gateway_sku" {
  type        = string
  description = "Azure VPN Gateway SKU."
  default     = "VpnGw1AZ"

  validation {
    condition     = var.vpn_gateway_sku == "VpnGw1AZ"
    error_message = "vpn_gateway_sku must be VpnGw1AZ."
  }
}

variable "log_analytics_workspace_name" {
  type        = string
  description = "Name of the Log Analytics workspace that receives Azure Firewall logs."
  default     = "law-mea-tech-community-day"
}

variable "log_analytics_retention_in_days" {
  type        = number
  description = "Log Analytics retention period in days."
  default     = 30

  validation {
    condition     = var.log_analytics_retention_in_days >= 30
    error_message = "log_analytics_retention_in_days must be at least 30."
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the lab resources."
  default = {
    workload    = "MEA-Tech-Community-Day"
    environment = "Lab"
  }
}
