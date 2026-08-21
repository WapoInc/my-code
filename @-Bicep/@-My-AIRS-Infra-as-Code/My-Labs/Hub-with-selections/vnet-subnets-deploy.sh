#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="$SCRIPT_DIR/vnet-subnets-rg.bicep"

region_options=(
  "southafricanorth"
  "southafricawest"
  "westeurope"
  "northeurope"
  "uksouth"
  "ukwest"
)

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

selected_indices=()
vnet_names=()
vnet_cidrs=()
resource_group_names=()

is_selected() {
  local candidate=$1
  local selected

  for selected in "${selected_indices[@]+"${selected_indices[@]}"}"; do
    [[ "$selected" == "$candidate" ]] && return 0
  done
  return 1
}

is_valid_cidr() {
  local cidr=$1
  local address prefix octet
  local -a octets

  [[ "$cidr" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/([0-9]|[12][0-9]|3[0-2])$ ]] || return 1
  address="${cidr%/*}"
  prefix="${cidr##*/}"
  IFS=. read -r -a octets <<< "$address"

  for octet in "${octets[@]}"; do
    (( 10#$octet <= 255 )) || return 1
  done

  (( 10#$prefix <= 29 ))
}

ensure_signed_in() {
  local subscription_id=$1
  local tenant_id=$2

  if ! az account show --subscription "$subscription_id" >/dev/null 2>&1; then
    echo "Signing in to tenant $tenant_id..."
    az login --tenant "$tenant_id" >/dev/null
  fi
  az account set --subscription "$subscription_id"
}

echo
echo "Select subscriptions. Choose Next when you are ready to enter VNet details:"
PS3="Enter selection: "

while true; do
  select choice in "${subscription_labels[@]}" "Next" "Cancel"; do
    case "$choice" in
      "Next")
        if (( ${#selected_indices[@]} == 0 )); then
          echo "Select at least one subscription before choosing Next."
          break
        fi
        selection_complete=true
        break
        ;;
      "Cancel")
        echo "Deployment cancelled."
        exit 0
        ;;
      "")
        echo "Invalid selection. Choose a number from 1 to $((${#subscription_ids[@]} + 2))."
        break
        ;;
      *)
        selected_index=$((REPLY - 1))
        if is_selected "$selected_index"; then
          echo "${subscription_labels[$selected_index]} is already selected."
        else
          selected_indices+=("$selected_index")
          echo "Added ${subscription_labels[$selected_index]}."
        fi
        break
        ;;
    esac
  done

  [[ "${selection_complete:-false}" == "true" ]] && break
  echo
  echo "Select another subscription, or choose Next:"
done

echo
echo "Select the Azure region for the VNets:"
PS3="Enter selection: "
select selected_region in "${region_options[@]}" "Cancel"; do
  if [[ "$selected_region" == "Cancel" ]]; then
    echo "Deployment cancelled."
    exit 0
  fi
  if [[ -n "$selected_region" ]]; then
    LOCATION="$selected_region"
    break
  fi
  echo "Invalid selection. Choose a number from 1 to $((${#region_options[@]} + 1))."
done

vnet_name_regex='^[A-Za-z0-9][A-Za-z0-9._-]{0,62}[A-Za-z0-9_]$|^[A-Za-z0-9]$'

for selected_index in "${selected_indices[@]}"; do
  echo
  echo "VNet for ${subscription_labels[$selected_index]}:"

  while true; do
    read -r -p "  VNet name: " VNET_NAME
    if [[ "$VNET_NAME" =~ $vnet_name_regex ]]; then
      break
    fi
    echo "  Use 1-64 letters, numbers, periods, hyphens, or underscores."
  done

  while true; do
    read -r -p "  VNet CIDR [10.10.0.0/16]: " VNET_CIDR
    VNET_CIDR="${VNET_CIDR:-10.10.0.0/16}"
    if is_valid_cidr "$VNET_CIDR"; then
      break
    fi
    echo "  Enter a valid IPv4 CIDR from /0 through /29, for example 10.10.0.0/16."
  done

  default_resource_group_name="${VNET_NAME}-rg"
  read -r -p "  Resource group name [${default_resource_group_name}]: " RESOURCE_GROUP_NAME
  RESOURCE_GROUP_NAME="${RESOURCE_GROUP_NAME:-$default_resource_group_name}"

  vnet_names+=("$VNET_NAME")
  vnet_cidrs+=("$VNET_CIDR")
  resource_group_names+=("$RESOURCE_GROUP_NAME")
done

echo
echo "VNets to create in $LOCATION:"
for position in "${!selected_indices[@]}"; do
  selected_index="${selected_indices[$position]}"
  echo "  ${subscription_labels[$selected_index]}"
  echo "    Resource group: ${resource_group_names[$position]}"
  echo "    VNet:           ${vnet_names[$position]}"
  echo "    CIDR:           ${vnet_cidrs[$position]}"
done

echo
read -r -p "Create these VNets? [y/N] " confirmation
if [[ ! "$confirmation" =~ ^[Yy]$ ]]; then
  echo "Deployment cancelled."
  exit 0
fi

for position in "${!selected_indices[@]}"; do
  selected_index="${selected_indices[$position]}"
  subscription_id="${subscription_ids[$selected_index]}"
  tenant_id="${subscription_tenants[$selected_index]}"

  echo
  echo "Deploying ${vnet_names[$position]} to ${subscription_labels[$selected_index]}..."
  ensure_signed_in "$subscription_id" "$tenant_id"

  az deployment sub create \
    --name "vnet-subnets-$(date -u +%Y%m%d-%H%M%S)-$position" \
    --location "$LOCATION" \
    --template-file "$TEMPLATE_FILE" \
    --parameters \
      resourceGroupName="${resource_group_names[$position]}" \
      location="$LOCATION" \
      vnetName="${vnet_names[$position]}" \
      vnetCidr="${vnet_cidrs[$position]}" \
    --subscription "$subscription_id"
done

echo
echo "All VNet deployments completed successfully."