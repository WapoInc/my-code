#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="$SCRIPT_DIR/main.bicep"

SUBSCRIPTION="${AZURE_SUBSCRIPTION:-ME-MngEnvMCAP158201-viresent-1}"
DEFAULT_RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-POC-Test-12-45-8-Oct}"
LOCATION="${AZURE_LOCATION:-southafricanorth}"
ADMIN_USERNAME="${ADMIN_USERNAME:-adminazure}"
AUTO_APPROVE="${AUTO_APPROVE:-false}"

for command_name in az python3; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Required command not found: $command_name" >&2
    exit 1
  fi
done

if ! az account show >/dev/null 2>&1; then
  echo "Sign in to Azure before running this script: az login" >&2
  exit 1
fi

az account set --subscription "$SUBSCRIPTION"

read -r -p "Resource group [$DEFAULT_RESOURCE_GROUP]: " RESOURCE_GROUP
RESOURCE_GROUP="${RESOURCE_GROUP:-$DEFAULT_RESOURCE_GROUP}"

if [[ -z "${ADMIN_PASSWORD:-}" ]]; then
  read -r -s -p "VM administrator password: " ADMIN_PASSWORD
  echo
fi

if [[ -z "${VPN_SHARED_KEY:-}" ]]; then
  read -r -s -p "VPN pre-shared key: " VPN_SHARED_KEY
  echo
fi

if [[ ${#ADMIN_PASSWORD} -lt 12 ]]; then
  echo "ADMIN_PASSWORD must be at least 12 characters." >&2
  exit 1
fi

if [[ -z "$VPN_SHARED_KEY" ]]; then
  echo "VPN_SHARED_KEY cannot be empty." >&2
  exit 1
fi

export ADMIN_PASSWORD VPN_SHARED_KEY ADMIN_USERNAME
PARAMETERS_FILE="$(mktemp)"
trap 'rm -f "$PARAMETERS_FILE"; unset ADMIN_PASSWORD VPN_SHARED_KEY' EXIT
chmod 600 "$PARAMETERS_FILE"

python3 - "$PARAMETERS_FILE" <<'PY'
import json
import os
import sys

parameters = {
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "adminUsername": {"value": os.environ["ADMIN_USERNAME"]},
        "adminPassword": {"value": os.environ["ADMIN_PASSWORD"]},
        "vpnSharedKey": {"value": os.environ["VPN_SHARED_KEY"]},
    },
}

with open(sys.argv[1], "w", encoding="utf-8") as parameters_file:
    json.dump(parameters, parameters_file)
PY

echo "Subscription: $SUBSCRIPTION"
echo "Resource group: $RESOURCE_GROUP"
echo "Location: $LOCATION"
echo "VPN gateway SKU: VpnGw1AZ"

az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --output none

az deployment group validate \
  --name "mea-tech-community-validate" \
  --resource-group "$RESOURCE_GROUP" \
  --template-file "$TEMPLATE_FILE" \
  --parameters "@$PARAMETERS_FILE" \
  --output none

DEPLOYMENT_NAME="mea-tech-community-$(date -u +%Y%m%d%H%M%S)"
DEPLOYMENT_ARGS=(
  --name "$DEPLOYMENT_NAME"
  --resource-group "$RESOURCE_GROUP"
  --template-file "$TEMPLATE_FILE"
  --parameters "@$PARAMETERS_FILE"
)

if [[ "$AUTO_APPROVE" == "true" ]]; then
  az deployment group create "${DEPLOYMENT_ARGS[@]}" --output table
else
  az deployment group create "${DEPLOYMENT_ARGS[@]}" --confirm-with-what-if --output table
fi

echo
echo "Deployment complete. Resource inventory:"
az resource list \
  --resource-group "$RESOURCE_GROUP" \
  --query "sort_by([].{Name:name, Type:type, Location:location}, &Type)" \
  --output table