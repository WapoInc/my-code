#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="${TEMPLATE_FILE:-$SCRIPT_DIR/main.bicep}"

DEFAULT_RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-POC-MEA-Comm-Day-Student}"
LOCATION="${AZURE_LOCATION:-southafricanorth}"
ADMIN_USERNAME="${ADMIN_USERNAME:-adminazure}"
AUTO_APPROVE="${AUTO_APPROVE:-false}"

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

CURRENT_TENANT=""
CURRENT_SUBSCRIPTION=""
if az account show >/dev/null 2>&1; then
  CURRENT_TENANT="$(az account show --query tenantId --output tsv)"
  CURRENT_SUBSCRIPTION="$(az account show --query id --output tsv)"
fi

DEFAULT_TENANT="${AZURE_TENANT_ID:-$CURRENT_TENANT}"
read -r -p "Tenant ID${DEFAULT_TENANT:+ [$DEFAULT_TENANT]}: " TENANT_INPUT
TENANT_ID="${TENANT_INPUT:-$DEFAULT_TENANT}"

if [[ -z "$CURRENT_TENANT" || ( -n "$TENANT_ID" && "$TENANT_ID" != "$CURRENT_TENANT" ) ]]; then
  if [[ -n "$TENANT_ID" ]]; then
    az login --tenant "$TENANT_ID" --output none
  else
    az login --output none
  fi
fi

TENANT_ID="${TENANT_ID:-$(az account show --query tenantId --output tsv)}"

echo
echo "Subscriptions available in tenant $TENANT_ID:"
az account list \
  --query "[?tenantId=='$TENANT_ID'].{Name:name, Subscription:id, Default:isDefault}" \
  --output table

CURRENT_SUBSCRIPTION="$(az account show --query id --output tsv)"
DEFAULT_SUBSCRIPTION="${AZURE_SUBSCRIPTION_ID:-${AZURE_SUBSCRIPTION:-$CURRENT_SUBSCRIPTION}}"
read -r -p "Subscription name or ID [$DEFAULT_SUBSCRIPTION]: " SUBSCRIPTION_INPUT
SUBSCRIPTION="${SUBSCRIPTION_INPUT:-$DEFAULT_SUBSCRIPTION}"

if [[ -z "$SUBSCRIPTION" ]]; then
  echo "A subscription name or ID is required." >&2
  exit 1
fi

az account set --subscription "$SUBSCRIPTION"

SELECTED_TENANT="$(az account show --query tenantId --output tsv)"
if [[ "$SELECTED_TENANT" != "$TENANT_ID" ]]; then
  echo "The selected subscription is not in tenant $TENANT_ID." >&2
  exit 1
fi

read -r -p "Resource group [$DEFAULT_RESOURCE_GROUP]: " RESOURCE_GROUP_INPUT
RESOURCE_GROUP="${RESOURCE_GROUP_INPUT:-$DEFAULT_RESOURCE_GROUP}"

if [[ -z "${ADMIN_PASSWORD:-}" ]]; then
  read -r -s -p "VM administrator password: " ADMIN_PASSWORD
  echo
fi

if [[ -z "${ONPREM_TO_AZURE_SHARED_KEY:-}" ]]; then
  read -r -s -p "On-premises-to-Azure VPN shared key: " ONPREM_TO_AZURE_SHARED_KEY
  echo
fi

if [[ -z "${AZURE_TO_ONPREM_SHARED_KEY:-}" ]]; then
  read -r -s -p "Azure-to-on-premises VPN shared key: " AZURE_TO_ONPREM_SHARED_KEY
  echo
fi

if [[ ${#ADMIN_PASSWORD} -lt 12 ]]; then
  echo "ADMIN_PASSWORD must be at least 12 characters." >&2
  exit 1
fi

if [[ -z "$ONPREM_TO_AZURE_SHARED_KEY" || -z "$AZURE_TO_ONPREM_SHARED_KEY" ]]; then
  echo "Both VPN shared keys are required." >&2
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

az deployment group validate "${COMMON_ARGS[@]}" --output none

DEPLOYMENT_NAME="mea-tech-student-$(date -u +%Y%m%d%H%M%S)"
DEPLOYMENT_ARGS=(
  --name "$DEPLOYMENT_NAME"
  "${COMMON_ARGS[@]}"
)

if [[ "$AUTO_APPROVE" == "true" ]]; then
  az deployment group create "${DEPLOYMENT_ARGS[@]}" --output table
else
  az deployment group create "${DEPLOYMENT_ARGS[@]}" --confirm-with-what-if --output table
fi

echo
echo "Deployment complete. Outputs:"
az deployment group show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$DEPLOYMENT_NAME" \
  --query properties.outputs \
  --output json