#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="$SCRIPT_DIR/final-deploy-za-east-hub-vpn-gw-fw.bicep"
MAX_DEPLOYMENT_ATTEMPTS=3

# These arrays are consumed by select_option through a Bash nameref.
# shellcheck disable=SC2034
region_options=(
  "southafricanorth"
  "southafricawest"
  "westeurope"
  "northeurope"
  "uksouth"
  "ukwest"
)

# shellcheck disable=SC2034
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

# shellcheck disable=SC2034
vpn_gateway_options=(
  "VpnGw1AZ"
  "VpnGw2AZ"
  "VpnGw3AZ"
  "VpnGw4AZ"
  "VpnGw5AZ"
)

# shellcheck disable=SC2034
azure_firewall_options=(
  "Basic"
  "Standard"
  "Premium"
)

select_option() {
  local prompt="$1"
  local options_name="$2"
  local -n options="$options_name"
  local selected_option

  echo "$prompt" >&2
  PS3="Enter selection (1-${#options[@]}): "
  select selected_option in "${options[@]}"; do
    if [[ -n "$selected_option" ]]; then
      printf '%s\n' "$selected_option"
      return
    fi
    echo "Invalid selection. Choose a number from 1 to ${#options[@]}." >&2
  done
}

if ! command -v az >/dev/null 2>&1; then
  echo "Azure CLI is not installed or is not in PATH." >&2
  exit 1
fi

if [[ ! -f "$TEMPLATE_FILE" ]]; then
  echo "Bicep template not found: $TEMPLATE_FILE" >&2
  exit 1
fi

echo "Final ZA-East Hub + VPN Gateway + Azure Firewall deployment"
echo

selected_subscription_label="$(select_option "Select the Azure subscription:" subscription_labels)"
selected_index=-1
for index in "${!subscription_labels[@]}"; do
  if [[ "${subscription_labels[$index]}" == "$selected_subscription_label" ]]; then
    selected_index=$index
    break
  fi
done

if (( selected_index < 0 )); then
  echo "Unable to resolve the selected subscription." >&2
  exit 1
fi

selected_subscription_id="${subscription_ids[$selected_index]}"
selected_tenant_id="${subscription_tenants[$selected_index]}"
LOCATION="$(select_option "Select the deployment region:" region_options)"
VPN_GATEWAY_SKU="$(select_option "Select the zone-redundant VPN Gateway SKU:" vpn_gateway_options)"
AZURE_FIREWALL_SKU="$(select_option "Select the Azure Firewall SKU:" azure_firewall_options)"

read -r -p "Resource group name [za-east-${LOCATION}]: " RESOURCE_GROUP_NAME
RESOURCE_GROUP_NAME="${RESOURCE_GROUP_NAME:-za-east-${LOCATION}}"
if [[ ! "$RESOURCE_GROUP_NAME" =~ ^[Zz][Aa]-[Ee][Aa][Ss][Tt]- ]]; then
  RESOURCE_GROUP_NAME="za-east-${RESOURCE_GROUP_NAME}"
fi

read -r -p "Create the FortiGate LNG and S2S connection? [Y/n] " create_lng_answer
if [[ "$create_lng_answer" =~ ^[Nn]$ ]]; then
  CREATE_FORTIGATE_LNG=false
else
  CREATE_FORTIGATE_LNG=true
fi

if [[ -z "${ADMIN_PASSWORD:-}" ]]; then
  read -r -s -p "VM administrator password: " ADMIN_PASSWORD
  echo
  read -r -s -p "Confirm VM administrator password: " ADMIN_PASSWORD_CONFIRM
  echo

  if [[ -z "$ADMIN_PASSWORD" ]]; then
    echo "The VM administrator password cannot be empty." >&2
    exit 1
  fi

  if [[ "$ADMIN_PASSWORD" != "$ADMIN_PASSWORD_CONFIRM" ]]; then
    echo "The passwords do not match." >&2
    exit 1
  fi
fi

FORTIGATE_PUBLIC_IP="156.155.28.158"
FORTIGATE_BGP_ASN=65521
FORTIGATE_BGP_PEER_IP="66.66.66.66"
AZURE_VPN_BGP_ASN=65515
AZURE_FIREWALL_NAME="AzFW-ZA-East-${LOCATION}"

echo
echo "Deployment target:"
echo "  Subscription:      $selected_subscription_label"
echo "  Subscription ID:   $selected_subscription_id"
echo "  Location:          $LOCATION"
echo "  Resource group:    $RESOURCE_GROUP_NAME"
echo "  VPN Gateway:       $VPN_GATEWAY_SKU"
echo "  Azure Firewall:    $AZURE_FIREWALL_SKU"
echo "  Firewall Policy:   ${AZURE_FIREWALL_NAME}-Policy"
echo "  FortiGate LNG/S2S: $CREATE_FORTIGATE_LNG"
echo "  Template:          $TEMPLATE_FILE"
echo

read -r -p "Continue with this deployment? [y/N] " confirmation
if [[ ! "$confirmation" =~ ^[Yy]$ ]]; then
  echo "Deployment cancelled."
  exit 0
fi

if ! az account show --subscription "$selected_subscription_id" >/dev/null 2>&1; then
  echo "Signing in to tenant $selected_tenant_id..."
  az login --tenant "$selected_tenant_id" >/dev/null
fi

az account set --subscription "$selected_subscription_id"

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

  echo "Removing failed Azure Firewall '$AZURE_FIREWALL_NAME' before retrying..."
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

remove_failed_azure_firewall || true

DEPLOYMENT_PARAMETERS=(
  "adminPassword=$ADMIN_PASSWORD"
  "location=$LOCATION"
  "resourceGroupName=$RESOURCE_GROUP_NAME"
  "vpnGatewaySku=$VPN_GATEWAY_SKU"
  "azureFirewallSku=$AZURE_FIREWALL_SKU"
  "enableFortiGateBgp=true"
  "createFortiGateLocalNetworkGateway=$CREATE_FORTIGATE_LNG"
  "fortiGatePublicIp=$FORTIGATE_PUBLIC_IP"
  "fortiGateBgpAsn=$FORTIGATE_BGP_ASN"
  "fortiGateBgpPeerIp=$FORTIGATE_BGP_PEER_IP"
  "azureVpnBgpAsn=$AZURE_VPN_BGP_ASN"
)

VALIDATION_NAME="final-za-east-validate-$(date -u +%Y%m%d-%H%M%S)"
echo "Validating the subscription deployment..."
az deployment sub validate \
  --name "$VALIDATION_NAME" \
  --location "$LOCATION" \
  --template-file "$TEMPLATE_FILE" \
  --parameters "${DEPLOYMENT_PARAMETERS[@]}" \
  --subscription "$selected_subscription_id" \
  --output none

deployment_succeeded=false
DEPLOYMENT_NAME=""

for ((attempt = 1; attempt <= MAX_DEPLOYMENT_ATTEMPTS; attempt++)); do
  DEPLOYMENT_NAME="final-za-east-$(date -u +%Y%m%d-%H%M%S)-${attempt}"
  echo "Starting deployment attempt $attempt of $MAX_DEPLOYMENT_ATTEMPTS..."

  if az deployment sub create \
    --name "$DEPLOYMENT_NAME" \
    --location "$LOCATION" \
    --template-file "$TEMPLATE_FILE" \
    --parameters "${DEPLOYMENT_PARAMETERS[@]}" \
    --subscription "$selected_subscription_id" \
    --output none; then
    deployment_succeeded=true
    break
  fi

  if ! remove_failed_azure_firewall; then
    echo "Deployment failed for a reason other than a failed Azure Firewall." >&2
    exit 1
  fi

  if (( attempt < MAX_DEPLOYMENT_ATTEMPTS )); then
    echo "Retrying after Azure Firewall cleanup..."
  fi
done

if [[ "$deployment_succeeded" != true ]]; then
  echo "Deployment failed after $MAX_DEPLOYMENT_ATTEMPTS attempts." >&2
  exit 1
fi

unset ADMIN_PASSWORD ADMIN_PASSWORD_CONFIRM

echo
echo "Deployment succeeded: $DEPLOYMENT_NAME"
az deployment sub show \
  --subscription "$selected_subscription_id" \
  --name "$DEPLOYMENT_NAME" \
  --query "properties.outputs.{resourceGroup:resourceGroupName.value,vpnGateway:vpnGatewayName.value,firewall:azureFirewallName.value,firewallPolicy:azureFirewallPolicyName.value,ruleCollectionGroup:azureFirewallRuleCollectionGroupName.value,firewallPrivateIp:azureFirewallPrivateIp.value}" \
  --output table
