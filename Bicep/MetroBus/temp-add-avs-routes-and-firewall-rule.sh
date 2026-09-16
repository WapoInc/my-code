#!/usr/bin/env bash

set -euo pipefail

SUBSCRIPTION="${AZURE_SUBSCRIPTION:-ME-MngEnvMCAP158201-viresent-1}"
RESOURCE_GROUP="${1:-${AZURE_RESOURCE_GROUP:-metro-bus-rg2}}"
FIREWALL_POLICY_NAME="AzFW-Policy-01"
RULE_COLLECTION_GROUP_NAME="DefaultNetworkRuleCollectionGroup"
RULE_COLLECTION_NAME="NetworkRuleCollection"

if ! command -v az >/dev/null 2>&1; then
  echo "Required command not found: az" >&2
  exit 1
fi

if ! az account show >/dev/null 2>&1; then
  echo "Sign in to Azure before running this script: az login" >&2
  exit 1
fi

az account set --subscription "$SUBSCRIPTION"

echo "Adding route-to-avs to azure-gateway-subnet-rt..."
az network route-table route create \
  --resource-group "$RESOURCE_GROUP" \
  --route-table-name "azure-gateway-subnet-rt" \
  --name "route-to-avs" \
  --address-prefix "172.16.1.0/24" \
  --next-hop-type "VirtualAppliance" \
  --next-hop-ip-address "10.70.3.4" \
  --output none

echo "Adding to-avs-vnet to azure-subnet-rt..."
az network route-table route create \
  --resource-group "$RESOURCE_GROUP" \
  --route-table-name "azure-subnet-rt" \
  --name "to-avs-vnet" \
  --address-prefix "172.16.1.0/24" \
  --next-hop-type "VirtualAppliance" \
  --next-hop-ip-address "10.70.3.4" \
  --output none

FIREWALL_RULE_ARGS=(
  --resource-group "$RESOURCE_GROUP"
  --policy-name "$FIREWALL_POLICY_NAME"
  --rule-collection-group-name "$RULE_COLLECTION_GROUP_NAME"
  --collection-name "$RULE_COLLECTION_NAME"
  --name "onprem-to-avs-vnet"
  --source-addresses "192.168.1.0/24"
  --destination-addresses "172.16.1.0/24"
  --ip-protocols "Any"
  --destination-ports "*"
)

if az network firewall policy rule-collection-group collection rule show \
  "${FIREWALL_RULE_ARGS[@]:0:10}" >/dev/null 2>&1; then
  echo "Updating Azure Firewall rule onprem-to-avs-vnet..."
  az network firewall policy rule-collection-group collection rule update \
    "${FIREWALL_RULE_ARGS[@]}" \
    --output none
else
  echo "Adding Azure Firewall rule onprem-to-avs-vnet..."
  az network firewall policy rule-collection-group collection rule add \
    "${FIREWALL_RULE_ARGS[@]}" \
    --rule-type "NetworkRule" \
    --output none
fi

echo "AVS routes and Azure Firewall rule applied successfully."
