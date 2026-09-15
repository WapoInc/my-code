#!/usr/bin/env bash

set -euo pipefail

DEFAULT_RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-POC-MEA-Comm-Day-Student}"
ADMIN_USERNAME="${ADMIN_USERNAME:-adminazure}"
VNET_NAME='azure-vnet'
SUBNET_NAME='azure-vm2-subnet'
SUBNET_PREFIX='10.70.2.0/24'
NIC_NAME='azure-vm2-nic'
VM_NAME='azure-vm2'
VM_SIZE='Standard_B2s'

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
  echo "Required command not found: az" >&2
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

  if [[ -n "$selected_label" && "$REPLY" =~ ^[0-9]+$ ]] &&
    (( REPLY >= 1 && REPLY <= ${#subscription_ids[@]} )); then
    selected_index=$((REPLY - 1))
    break
  fi

  echo "Invalid selection. Choose a number from 1 to $((${#subscription_ids[@]} + 1))."
done

selected_subscription_id="${subscription_ids[$selected_index]}"
selected_tenant_id="${subscription_tenants[$selected_index]}"

if ! az account show --subscription "$selected_subscription_id" >/dev/null 2>&1; then
  echo "Signing in to tenant $selected_tenant_id..."
  az login --tenant "$selected_tenant_id" --output none
fi

az account set --subscription "$selected_subscription_id"

TENANT_ID="$(az account show --query tenantId --output tsv)"
SUBSCRIPTION_ID="$(az account show --query id --output tsv)"
if [[ "$TENANT_ID" != "$selected_tenant_id" || "$SUBSCRIPTION_ID" != "$selected_subscription_id" ]]; then
  echo "Azure CLI did not switch to the selected tenant and subscription." >&2
  exit 1
fi

read -r -p "Resource group [$DEFAULT_RESOURCE_GROUP]: " RESOURCE_GROUP_INPUT
RESOURCE_GROUP="${RESOURCE_GROUP_INPUT:-$DEFAULT_RESOURCE_GROUP}"

if ! az group show --name "$RESOURCE_GROUP" --output none 2>/dev/null; then
  echo "Resource group not found: $RESOURCE_GROUP" >&2
  exit 1
fi

if ! az network vnet show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VNET_NAME" \
  --output none 2>/dev/null; then
  echo "Existing virtual network not found: $VNET_NAME" >&2
  exit 1
fi

LOCATION="$(az network vnet show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VNET_NAME" \
  --query location \
  --output tsv)"

BOOT_DIAGNOSTICS_STORAGE="$(az storage account list \
  --resource-group "$RESOURCE_GROUP" \
  --query "[?starts_with(name, 'bootdiag')].name | [0]" \
  --output tsv)"

if [[ -z "$BOOT_DIAGNOSTICS_STORAGE" ]]; then
  echo "Existing boot diagnostics storage account was not found." >&2
  exit 1
fi

if [[ -z "${ADMIN_PASSWORD:-}" ]]; then
  read -r -s -p "VM administrator password: " ADMIN_PASSWORD
  echo
fi
trap 'unset ADMIN_PASSWORD' EXIT

if [[ ${#ADMIN_PASSWORD} -lt 12 ]]; then
  echo "ADMIN_PASSWORD must be at least 12 characters." >&2
  exit 1
fi

echo
echo "Subscription:   $(az account show --query name --output tsv) ($SUBSCRIPTION_ID)"
echo "Resource group: $RESOURCE_GROUP"
echo "Location:       $LOCATION"
echo "Virtual network: $VNET_NAME"

if az network vnet subnet show \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --name "$SUBNET_NAME" \
  --output none 2>/dev/null; then
  existing_prefix="$(az network vnet subnet show \
    --resource-group "$RESOURCE_GROUP" \
    --vnet-name "$VNET_NAME" \
    --name "$SUBNET_NAME" \
    --query addressPrefix \
    --output tsv)"
  existing_route_table="$(az network vnet subnet show \
    --resource-group "$RESOURCE_GROUP" \
    --vnet-name "$VNET_NAME" \
    --name "$SUBNET_NAME" \
    --query routeTable.id \
    --output tsv)"

  if [[ "$existing_prefix" != "$SUBNET_PREFIX" ]]; then
    echo "$SUBNET_NAME already exists with prefix $existing_prefix, expected $SUBNET_PREFIX." >&2
    exit 1
  fi
  if [[ -n "$existing_route_table" ]]; then
    echo "$SUBNET_NAME already has a route table attached; no changes were made." >&2
    exit 1
  fi
  echo "Subnet already exists: $SUBNET_NAME"
else
  echo "Creating subnet: $SUBNET_NAME ($SUBNET_PREFIX)"
  az network vnet subnet create \
    --resource-group "$RESOURCE_GROUP" \
    --vnet-name "$VNET_NAME" \
    --name "$SUBNET_NAME" \
    --address-prefixes "$SUBNET_PREFIX" \
    --output none
fi

if az network nic show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$NIC_NAME" \
  --output none 2>/dev/null; then
  echo "Network interface already exists: $NIC_NAME"
else
  echo "Creating network interface: $NIC_NAME"
  az network nic create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$NIC_NAME" \
    --location "$LOCATION" \
    --vnet-name "$VNET_NAME" \
    --subnet "$SUBNET_NAME" \
    --output none
fi

if az vm show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VM_NAME" \
  --output none 2>/dev/null; then
  echo "Virtual machine already exists: $VM_NAME"
else
  echo "Creating virtual machine: $VM_NAME"
  az vm create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VM_NAME" \
    --location "$LOCATION" \
    --nics "$NIC_NAME" \
    --image 'Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest' \
    --admin-username "$ADMIN_USERNAME" \
    --admin-password "$ADMIN_PASSWORD" \
    --size "$VM_SIZE" \
    --storage-sku 'Standard_LRS' \
    --boot-diagnostics-storage "$BOOT_DIAGNOSTICS_STORAGE" \
    --output none
fi

PRIVATE_IP="$(az network nic show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$NIC_NAME" \
  --query 'ipConfigurations[0].privateIPAddress' \
  --output tsv)"

echo
echo "Temporary VM deployment complete."
echo "VM:         $VM_NAME"
echo "Size:       $VM_SIZE"
echo "Subnet:     $SUBNET_NAME ($SUBNET_PREFIX)"
echo "Private IP: $PRIVATE_IP"
echo "No route table or Azure Firewall configuration was changed."