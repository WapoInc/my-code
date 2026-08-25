#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="$SCRIPT_DIR/ZA-East-Hub-resources-rg.bicep"

echo "ZA-East deployment runner v2026.08.24.2 (firewall policy + automatic retry)"

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
FORTIGATE_BGP_ASN=65521
FORTIGATE_BGP_PEER_IP="66.66.66.66"
AZURE_VPN_BGP_ASN=65515

# --- Prompt for ZA-East-Hub-resources-rg.bicep parameters (Enter accepts default) ---
read -r -p "Resource group name [za-east-${LOCATION}]: " RESOURCE_GROUP_NAME
RESOURCE_GROUP_NAME="${RESOURCE_GROUP_NAME:-za-east-${LOCATION}}"
if [[ ! "$RESOURCE_GROUP_NAME" =~ ^[Zz][Aa]-[Ee][Aa][Ss][Tt]- ]]; then
  RESOURCE_GROUP_NAME="za-east-${RESOURCE_GROUP_NAME}"
fi

vpn_gateway_options=(
  "None"
  "VpnGw1AZ"
  "VpnGw2AZ"
  "VpnGw3AZ"
  "VpnGw4AZ"
  "VpnGw5AZ"
)

echo
echo "Select the VPN gateway SKU:"
echo "  Only zone-redundant Azure VPN Gateway SKUs are offered."
PS3="Enter selection (1-${#vpn_gateway_options[@]}): "

VPN_GATEWAY_SKU=""
select selected_vpn_gateway_sku in "${vpn_gateway_options[@]}"; do
  if [[ -n "$selected_vpn_gateway_sku" ]]; then
    VPN_GATEWAY_SKU="$selected_vpn_gateway_sku"
    break
  fi

  echo "Invalid selection. Choose a number from 1 to ${#vpn_gateway_options[@]}."
done

azure_firewall_options=(
  "None"
  "Basic"
  "Standard"
  "Premium"
)

echo
echo "Select the Azure Firewall SKU:"
PS3="Enter selection (1-${#azure_firewall_options[@]}): "

AZURE_FIREWALL_SKU=""
select selected_azure_firewall_sku in "${azure_firewall_options[@]}"; do
  if [[ -n "$selected_azure_firewall_sku" ]]; then
    AZURE_FIREWALL_SKU="$selected_azure_firewall_sku"
    break
  fi

  echo "Invalid selection. Choose a number from 1 to ${#azure_firewall_options[@]}."
done

lng_options=(
  "Yes"
  "No"
)

echo
echo "Create VPN GW - LNG?"
PS3="Enter selection (1-${#lng_options[@]}): "

CREATE_FORTIGATE_LNG=""
select selected_lng_option in "${lng_options[@]}"; do
  case "$selected_lng_option" in
    Yes)
      CREATE_FORTIGATE_LNG=true
      break
      ;;
    No)
      CREATE_FORTIGATE_LNG=false
      break
      ;;
    *)
      echo "Invalid selection. Choose 1 for Yes or 2 for No."
      ;;
  esac
done

FORTIGATE_TUNNEL="Skipped"
if [[ "$CREATE_FORTIGATE_LNG" == true && "$VPN_GATEWAY_SKU" != "None" ]]; then
  FORTIGATE_TUNNEL="Enabled (156.155.28.158, ASN ${FORTIGATE_BGP_ASN}, BGP peer ${FORTIGATE_BGP_PEER_IP})"
elif [[ "$CREATE_FORTIGATE_LNG" == true ]]; then
  FORTIGATE_TUNNEL="Skipped (LNG enabled, but VPN gateway is None)"
fi

echo
echo "Deployment target:"
echo "  Subscription:   ${subscription_labels[$selected_index]}"
echo "  ID:             $selected_subscription_id"
echo "  Tenant:         $selected_tenant_id"
echo "  Location:       $LOCATION"
echo "  Resource grp:   $RESOURCE_GROUP_NAME"
echo "  VPN gateway:    $VPN_GATEWAY_SKU"
echo "  Azure Firewall: $AZURE_FIREWALL_SKU"
echo "  Create LNG:     $CREATE_FORTIGATE_LNG"
echo "  FortiGate VPN:  $FORTIGATE_TUNNEL"
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

AZURE_FIREWALL_NAME="AzFW-ZA-East-${LOCATION}"

remove_failed_azure_firewall() {
  local firewall_state

  firewall_state="$(az network firewall show \
    --subscription "$selected_subscription_id" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$AZURE_FIREWALL_NAME" \
    --query provisioningState \
    --output tsv 2>/dev/null || true)"

  if [[ "$firewall_state" != "Failed" ]]; then
    return 1
  fi

  echo "Removing failed Azure Firewall '$AZURE_FIREWALL_NAME' before retrying deployment..."
  az network firewall delete \
    --subscription "$selected_subscription_id" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$AZURE_FIREWALL_NAME"

  az resource wait \
    --subscription "$selected_subscription_id" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --resource-type Microsoft.Network/azureFirewalls \
    --name "$AZURE_FIREWALL_NAME" \
    --deleted
}

if [[ "$AZURE_FIREWALL_SKU" != "None" ]]; then
  remove_failed_azure_firewall || true
fi

DEPLOYMENT_PARAMETERS=(
  "adminPassword=$ADMIN_PASSWORD"
  "location=$LOCATION"
  "resourceGroupName=$RESOURCE_GROUP_NAME"
  "vpnGatewaySku=$VPN_GATEWAY_SKU"
  "azureFirewallSku=$AZURE_FIREWALL_SKU"
  "enableFortiGateBgp=true"
  "createFortiGateLocalNetworkGateway=$CREATE_FORTIGATE_LNG"
  "fortiGateBgpAsn=$FORTIGATE_BGP_ASN"
  "fortiGateBgpPeerIp=$FORTIGATE_BGP_PEER_IP"
  "azureVpnBgpAsn=$AZURE_VPN_BGP_ASN"
)

VALIDATION_NAME="za-east-hub-validate-$(date -u +%Y%m%d-%H%M%S)"
echo "Validating the subscription deployment..."
az deployment sub validate \
  --name "$VALIDATION_NAME" \
  --location "$LOCATION" \
  --template-file "$TEMPLATE_FILE" \
  --parameters "${DEPLOYMENT_PARAMETERS[@]}" \
  --subscription "$selected_subscription_id" \
  --output none

MAX_DEPLOYMENT_ATTEMPTS=3
deployment_succeeded=false

for ((attempt = 1; attempt <= MAX_DEPLOYMENT_ATTEMPTS; attempt++)); do
  DEPLOYMENT_NAME="za-east-hub-$(date -u +%Y%m%d-%H%M%S)-${attempt}"
  echo "Starting deployment attempt $attempt of $MAX_DEPLOYMENT_ATTEMPTS..."

  if az deployment sub create \
    --name "$DEPLOYMENT_NAME" \
    --location "$LOCATION" \
    --template-file "$TEMPLATE_FILE" \
    --parameters "${DEPLOYMENT_PARAMETERS[@]}" \
    --subscription "$selected_subscription_id"; then
    deployment_succeeded=true
    break
  fi

  if [[ "$AZURE_FIREWALL_SKU" == "None" ]] || ! remove_failed_azure_firewall; then
    echo "Deployment failed for a reason other than a failed Azure Firewall. Not retrying automatically." >&2
    exit 1
  fi

  if (( attempt == MAX_DEPLOYMENT_ATTEMPTS )); then
    break
  fi

  echo "Retrying after Azure Firewall cleanup..."
done

if [[ "$deployment_succeeded" != true ]]; then
  echo "Deployment failed after $MAX_DEPLOYMENT_ATTEMPTS attempts." >&2
  exit 1
fi

if [[ "$VPN_GATEWAY_SKU" != "None" ]]; then
  GATEWAY_PIP_NAME="za-east-VPN-Gateway-${LOCATION}-${VPN_GATEWAY_SKU}-zones123-pip"
  GATEWAY_PUBLIC_IP="$(az network public-ip show \
    --subscription "$selected_subscription_id" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$GATEWAY_PIP_NAME" \
    --query ipAddress \
    --output tsv)"
  echo "VPN gateway public IP: $GATEWAY_PUBLIC_IP"
fi
