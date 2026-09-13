#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="$SCRIPT_DIR/log-analytics.bicep"

SUBSCRIPTION="${AZURE_SUBSCRIPTION:-ME-MngEnvMCAP158201-viresent-1}"
DEFAULT_RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-POC-Test-12-45-8-Oct}"
LOCATION="${AZURE_LOCATION:-southafricanorth}"
FIREWALL_NAME="${AZURE_FIREWALL_NAME:-AzFW}"

command -v az >/dev/null 2>&1 || {
  echo "Azure CLI is not installed or is not in PATH." >&2
  exit 1
}

[[ -f "$TEMPLATE_FILE" ]] || {
  echo "Bicep template not found: $TEMPLATE_FILE" >&2
  exit 1
}

az account show >/dev/null 2>&1 || {
  echo "Sign in to Azure before running this script: az login" >&2
  exit 1
}

az account set --subscription "$SUBSCRIPTION"

read -r -p "Resource group [$DEFAULT_RESOURCE_GROUP]: " RESOURCE_GROUP_INPUT
RESOURCE_GROUP="${RESOURCE_GROUP_INPUT:-$DEFAULT_RESOURCE_GROUP}"

az group show --name "$RESOURCE_GROUP" --output none || {
  echo "Resource group not found: $RESOURCE_GROUP" >&2
  exit 1
}

az network firewall show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$FIREWALL_NAME" \
  --output none || {
  echo "Azure Firewall not found: $RESOURCE_GROUP/$FIREWALL_NAME" >&2
  exit 1
}

DEPLOYMENT_NAME="mea-tech-log-analytics-$(date -u +%Y%m%d%H%M%S)"

az deployment group create \
  --name "$DEPLOYMENT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --template-file "$TEMPLATE_FILE" \
  --parameters \
    location="$LOCATION" \
    firewallName="$FIREWALL_NAME" \
  --output table

echo
echo "Log Analytics workspace and AZFWNetworkRule diagnostics deployed."
az deployment group show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$DEPLOYMENT_NAME" \
  --query properties.outputs \
  --output json