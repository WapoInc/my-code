#!/usr/bin/env bash

set -euo pipefail

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
vnet_names=(
  "1-vnet"
  "2-vnet"
  "3-vnet"
)

if ! command -v az >/dev/null 2>&1; then
  echo "Azure CLI is not installed or is not in PATH." >&2
  exit 1
fi

ensure_signed_in() {
  local subscription_id=$1
  local tenant_id=$2

  if ! az account show --subscription "$subscription_id" >/dev/null 2>&1; then
    echo "Signing in to tenant $tenant_id..."
    az login --tenant "$tenant_id" >/dev/null
  fi
  az account set --subscription "$subscription_id"
}

resource_group_from_id() {
  local resource_id=$1
  local resource_group_segment

  resource_group_segment="${resource_id#*/resourceGroups/}"
  echo "${resource_group_segment%%/*}"
}

create_peering() {
  local local_index=$1
  local remote_index=$2
  local peering_name="${vnet_names[$local_index]}-to-${vnet_names[$remote_index]}"
  local command_output

  ensure_signed_in "${subscription_ids[$local_index]}" "${subscription_tenants[$local_index]}"
  if ! command_output="$(az network vnet peering create \
      --name "$peering_name" \
      --resource-group "${resource_group_names[$local_index]}" \
      --vnet-name "${vnet_names[$local_index]}" \
      --remote-vnet "${vnet_ids[$remote_index]}" \
      --allow-vnet-access true \
      --subscription "${subscription_ids[$local_index]}" \
      --output none 2>&1)"; then
    echo "$command_output" >&2
    if [[ "$command_output" == *"AADSTS90072"* ]]; then
      echo >&2
      echo "Cross-tenant access is not configured for this peering direction." >&2
      echo "Account '${account_names[$local_index]}' must:" >&2
      echo "  1. Be invited to tenant ${subscription_tenants[$remote_index]} as a guest." >&2
      echo "  2. Accept the guest invitation." >&2
      echo "  3. Have Network Contributor on ${vnet_ids[$remote_index]}." >&2
    fi
    return 1
  fi
}

vnet_ids=()
resource_group_names=()
account_names=()

echo
echo "Finding the existing VNets..."

for index in "${!subscription_ids[@]}"; do
  ensure_signed_in "${subscription_ids[$index]}" "${subscription_tenants[$index]}"

  vnet_id="$(az network vnet list \
    --subscription "${subscription_ids[$index]}" \
    --query "[?name == '${vnet_names[$index]}'].id | [0]" \
    --output tsv)"

  if [[ -z "$vnet_id" ]]; then
    echo "VNet '${vnet_names[$index]}' was not found in ${subscription_labels[$index]}." >&2
    exit 1
  fi

  vnet_ids+=("$vnet_id")
  resource_group_names+=("$(resource_group_from_id "$vnet_id")")
  account_names+=("$(az account show \
    --subscription "${subscription_ids[$index]}" \
    --query user.name \
    --output tsv)")
done

echo
echo "Peerings to create:"
echo "  ${vnet_names[0]} <-> ${vnet_names[1]}"
echo "  ${vnet_names[0]} <-> ${vnet_names[2]}"
echo
echo "Existing VNets:"
for index in "${!vnet_ids[@]}"; do
  echo "  ${vnet_names[$index]}"
  echo "    Subscription:   ${subscription_labels[$index]}"
  echo "    Resource group: ${resource_group_names[$index]}"
  echo "    Account:        ${account_names[$index]}"
done

echo
echo "Cross-tenant access required before peering (choose one model):"
echo "  Recommended: use ${account_names[0]} for all three subscriptions."
echo "    Add it as a guest in tenants 2 and 3, accept both invitations,"
echo "    and assign it Network Contributor on 2-vnet and 3-vnet."
echo "  Separate accounts: also add each spoke account as a guest in tenant 1"
echo "    and assign it Network Contributor on 1-vnet."

echo
read -r -p "Create these peerings? [y/N] " confirmation
if [[ ! "$confirmation" =~ ^[Yy]$ ]]; then
  echo "Peering cancelled."
  exit 0
fi

echo
echo "Creating bidirectional peering between 1-vnet and 2-vnet..."
create_peering 0 1
create_peering 1 0

echo "Creating bidirectional peering between 1-vnet and 3-vnet..."
create_peering 0 2
create_peering 2 0

echo
echo "All VNet peerings completed successfully."