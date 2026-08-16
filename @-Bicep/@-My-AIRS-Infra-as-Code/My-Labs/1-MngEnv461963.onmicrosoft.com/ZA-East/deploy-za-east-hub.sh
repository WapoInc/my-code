#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="$SCRIPT_DIR/ZA-East-Hub-resources-rg.bicep"

# --- Selectable deployment regions ---
region_options=(
  "southafricanorth"
  "southafricawest"
  "westeurope"
  "northeurope"
  "uksouth"
  "ukwest"
)

# --- Selectable subscriptions (label | subscription id | tenant id) ---
subscription_labels=(
  "MngEnv461963 (5cba78fe tenant)"
  "MngEnvMCAP056429 (b91a5236 tenant)"
  "MngEnvMCAP158201 (2b8e427b tenant)"
)
subscription_ids=(
  "0cfd0d2a-2b38-4c93-ba14-cf79185bc683"
  "29df7078-c53c-4638-81c1-e4bc8566d423"
  "2ac21ef0-69db-49ec-a554-2cac36ec75f4"
)
subscription_tenants=(
  "5cba78fe-cc40-479a-9ee1-255423641bc9"
  "b91a5236-cd06-4bc7-889b-db71c19230ae"
  "2b8e427b-9e78-4589-9338-f870c84292ca"
)

if ! command -v az >/dev/null 2>&1; then
  echo "Azure CLI is not installed or is not in PATH." >&2
  exit 1
fi

echo
echo "Select the Azure subscription for this deployment:"
PS3="Enter selection (1-${#subscription_ids[@]}): "

selected_index=""
select selected_label in "${subscription_labels[@]}" "Cancel"; do
  if [[ "$selected_label" == "Cancel" ]]; then
    echo "Deployment cancelled."
    exit 0
  fi

  if [[ -n "$selected_label" && "$REPLY" =~ ^[0-9]+$ ]] && (( REPLY <= ${#subscription_ids[@]} )); then
    selected_index=$((REPLY - 1))
    break
  fi

  echo "Invalid selection. Choose a number from 1 to $((${#subscription_ids[@]} + 1))."
done

selected_subscription_id="${subscription_ids[$selected_index]}"
selected_tenant_id="${subscription_tenants[$selected_index]}"

echo
echo "Select the deployment region:"
PS3="Enter selection (1-${#region_options[@]}): "

LOCATION=""
select selected_region in "${region_options[@]}" "Cancel"; do
  if [[ "$selected_region" == "Cancel" ]]; then
    echo "Deployment cancelled."
    exit 0
  fi

  if [[ -n "$selected_region" && "$REPLY" =~ ^[0-9]+$ ]] && (( REPLY <= ${#region_options[@]} )); then
    LOCATION="$selected_region"
    break
  fi

  echo "Invalid selection. Choose a number from 1 to $((${#region_options[@]} + 1))."
done

ADMIN_PASSWORD="P@ssw0rd123!"

# --- Prompt for ZA-East-Hub-resources-rg.bicep parameters (Enter accepts default) ---
read -r -p "Resource group name [za-east-${LOCATION}]: " RESOURCE_GROUP_NAME
RESOURCE_GROUP_NAME="${RESOURCE_GROUP_NAME:-za-east-${LOCATION}}"

vpn_gateway_options=(
  "None"
  "Basic"
  "VpnGw1AZ"
  "VpnGw2AZ"
  "VpnGw3AZ"
  "VpnGw4AZ"
  "VpnGw5AZ"
)

echo
echo "Select the VPN gateway SKU:"
echo "  Basic is the supported non-AZ option; VpnGw1-5 non-AZ SKUs are blocked for new gateways."
PS3="Enter selection (1-${#vpn_gateway_options[@]}): "

VPN_GATEWAY_SKU=""
select selected_vpn_gateway_sku in "${vpn_gateway_options[@]}"; do
  if [[ -n "$selected_vpn_gateway_sku" ]]; then
    VPN_GATEWAY_SKU="$selected_vpn_gateway_sku"
    break
  fi

  echo "Invalid selection. Choose a number from 1 to ${#vpn_gateway_options[@]}."
done

echo
echo "Deployment target:"
echo "  Subscription:   ${subscription_labels[$selected_index]}"
echo "  ID:             $selected_subscription_id"
echo "  Tenant:         $selected_tenant_id"
echo "  Location:       $LOCATION"
echo "  Resource grp:   $RESOURCE_GROUP_NAME"
echo "  VPN gateway:    $VPN_GATEWAY_SKU"
echo "  Template:       $TEMPLATE_FILE"
echo

read -r -p "Continue with this subscription? [y/N] " confirmation
if [[ ! "$confirmation" =~ ^[Yy]$ ]]; then
  echo "Deployment cancelled."
  exit 0
fi

# Ensure signed in to the correct tenant and that the subscription is visible.
if ! az account show --subscription "$selected_subscription_id" >/dev/null 2>&1; then
  echo "Signing in to tenant $selected_tenant_id..."
  az login --tenant "$selected_tenant_id" >/dev/null
fi

az account set --subscription "$selected_subscription_id"

az deployment sub create \
  --name "za-east-hub-$(date -u +%Y%m%d-%H%M%S)" \
  --location "$LOCATION" \
  --template-file "$TEMPLATE_FILE" \
  --parameters \
    adminPassword="$ADMIN_PASSWORD" \
    location="$LOCATION" \
    resourceGroupName="$RESOURCE_GROUP_NAME" \
    vpnGatewaySku="$VPN_GATEWAY_SKU" \
  --subscription "$selected_subscription_id"
