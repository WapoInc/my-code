#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="${TEMPLATE_FILE:-$SCRIPT_DIR/main.bicep}"

DEFAULT_RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-POC-MEA-Comm-Day-Student}"
LOCATION="${AZURE_LOCATION:-southafricanorth}"
ADMIN_USERNAME="${ADMIN_USERNAME:-adminazure}"
ONPREM_TO_AZURE_SHARED_KEY='S2SPSK1!'
AZURE_TO_ONPREM_SHARED_KEY='S2SPSK2!'

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

MODE="deploy"
case "${1:-}" in
  --what-if) MODE="what-if" ;;
  --validate) MODE="validate" ;;
  "") ;;
  *) echo "Unknown argument: $1" >&2; exit 1 ;;
esac

for command_name in az python3; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Required command not found: $command_name" >&2
    exit 1
  fi
done

if [[ ! -f "$TEMPLATE_FILE" ]]; then
  echo "Bicep template not found: $TEMPLATE_FILE" >&2
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

if [[ -z "${ADMIN_PASSWORD:-}" ]]; then
  read -r -s -p "VM administrator password: " ADMIN_PASSWORD
  echo
fi

if [[ ${#ADMIN_PASSWORD} -lt 12 ]]; then
  echo "ADMIN_PASSWORD must be at least 12 characters." >&2
  exit 1
fi

export ADMIN_PASSWORD ONPREM_TO_AZURE_SHARED_KEY AZURE_TO_ONPREM_SHARED_KEY
export ADMIN_USERNAME LOCATION

PARAMETERS_FILE="$(mktemp)"
trap 'rm -f "$PARAMETERS_FILE"; unset ADMIN_PASSWORD ONPREM_TO_AZURE_SHARED_KEY AZURE_TO_ONPREM_SHARED_KEY' EXIT
chmod 600 "$PARAMETERS_FILE"

python3 - "$PARAMETERS_FILE" <<'PY'
import json
import os
import sys

parameters = {
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "location": {"value": os.environ["LOCATION"]},
        "adminUsername": {"value": os.environ["ADMIN_USERNAME"]},
        "adminPassword": {"value": os.environ["ADMIN_PASSWORD"]},
        "onpremToAzureSharedKey": {"value": os.environ["ONPREM_TO_AZURE_SHARED_KEY"]},
        "azureToOnpremSharedKey": {"value": os.environ["AZURE_TO_ONPREM_SHARED_KEY"]},
    },
}

with open(sys.argv[1], "w", encoding="utf-8") as parameters_file:
    json.dump(parameters, parameters_file)
PY

SUBSCRIPTION_NAME="$(az account show --query name --output tsv)"
SUBSCRIPTION_ID="$(az account show --query id --output tsv)"

echo
echo "Tenant:         $TENANT_ID"
echo "Subscription:   $SUBSCRIPTION_NAME ($SUBSCRIPTION_ID)"
echo "Resource group: $RESOURCE_GROUP"
echo "Location:       $LOCATION"

az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --output none

COMMON_ARGS=(
  --resource-group "$RESOURCE_GROUP"
  --template-file "$TEMPLATE_FILE"
  --parameters "@$PARAMETERS_FILE"
)

case "$MODE" in
  validate)
    az deployment group validate "${COMMON_ARGS[@]}" --output table
    exit 0
    ;;
  what-if)
    az deployment group what-if "${COMMON_ARGS[@]}"
    exit 0
    ;;
esac

legacy_gateway_exists=false
for legacy_gateway_name in onprem-gateway azure-gateway; do
  if az network vnet-gateway show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$legacy_gateway_name" \
    --output none 2>/dev/null; then
    legacy_gateway_exists=true
  fi
done

legacy_lng_exists=false
for legacy_lng_name in onprem-local-gateway azure-local-gateway; do
  if az network local-gateway show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$legacy_lng_name" \
    --output none 2>/dev/null; then
    legacy_lng_exists=true
  fi
done

if [[ "$legacy_gateway_exists" == "true" || "$legacy_lng_exists" == "true" ]]; then
  echo
  echo "Removing legacy gateway resources that conflict with the renamed deployment..."

  while IFS=$'\t' read -r connection_name virtual_gateway_id local_gateway_id; do
    if [[ -z "$connection_name" ]]; then
      continue
    fi

    if [[ "$virtual_gateway_id" == */virtualNetworkGateways/onprem-gateway ||
      "$virtual_gateway_id" == */virtualNetworkGateways/azure-gateway ||
      "$local_gateway_id" == */localNetworkGateways/onprem-local-gateway ||
      "$local_gateway_id" == */localNetworkGateways/azure-local-gateway ]]; then
      echo "Deleting legacy VPN connection: $connection_name"
      az network vpn-connection delete \
        --resource-group "$RESOURCE_GROUP" \
        --name "$connection_name" \
        --output none
    fi
  done < <(az network vpn-connection list \
    --resource-group "$RESOURCE_GROUP" \
    --query "[].[name, virtualNetworkGateway1.id, localNetworkGateway2.id]" \
    --output tsv)

  for legacy_gateway_name in onprem-gateway azure-gateway; do
    if az network vnet-gateway show \
      --resource-group "$RESOURCE_GROUP" \
      --name "$legacy_gateway_name" \
      --output none 2>/dev/null; then
      echo "Deleting legacy VPN gateway: $legacy_gateway_name"
      az network vnet-gateway delete \
        --resource-group "$RESOURCE_GROUP" \
        --name "$legacy_gateway_name" \
        --output none
    fi
  done

  for legacy_lng_name in onprem-local-gateway azure-local-gateway; do
    if az network local-gateway show \
      --resource-group "$RESOURCE_GROUP" \
      --name "$legacy_lng_name" \
      --output none 2>/dev/null; then
      echo "Deleting legacy local network gateway: $legacy_lng_name"
      az network local-gateway delete \
        --resource-group "$RESOURCE_GROUP" \
        --name "$legacy_lng_name" \
        --output none
    fi
  done
fi

az deployment group validate "${COMMON_ARGS[@]}" --output none

DEPLOYMENT_NAME="mea-tech-student-$(date -u +%Y%m%d%H%M%S)"
DEPLOYMENT_ARGS=(
  --name "$DEPLOYMENT_NAME"
  "${COMMON_ARGS[@]}"
)

az deployment group create "${DEPLOYMENT_ARGS[@]}" --output table

echo
echo "Deployment complete. Outputs:"
az deployment group show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$DEPLOYMENT_NAME" \
  --query properties.outputs \
  --output json