#!/usr/bin/env bash

set -euo pipefail

SCRIPT_START_EPOCH="$(date +%s)"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="$SCRIPT_DIR/main.bicep"

SUBSCRIPTION="${AZURE_SUBSCRIPTION:-ME-MngEnvMCAP158201-viresent-1}"
DEFAULT_RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-metro-bus-rg}"
LOCATION="${AZURE_LOCATION:-southafricanorth}"
ADMIN_USERNAME="${ADMIN_USERNAME:-adminazure}"

if [[ -n "${1:-}" ]]; then
  echo "Unknown argument: $1" >&2
  exit 1
fi

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
echo "Azure VPN gateway: VpnGw1AZ, active-active, ASN 65515"
echo "AVS gateway transit: azure-vnet -> avs-vnet"
echo "AVS return prefix: 172.16.1.0/24"
echo "Log Analytics: workspace and AzureFirewallNetworkRule diagnostics included"

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

az deployment group create "${DEPLOYMENT_ARGS[@]}" --output table

echo
echo "Deployment complete. Resource inventory:"
az resource list \
  --resource-group "$RESOURCE_GROUP" \
  --query "sort_by([].{Name:name, Type:type, Location:location}, &Type)" \
  --output table

echo
echo "Azure Route Server peer:"
az network routeserver peering show \
  --resource-group "$RESOURCE_GROUP" \
  --routeserver "azure-route-server" \
  --name "hub-vm" \
  --query "{Name:name, PeerIp:peerIp, PeerAsn:peerAsn, ProvisioningState:provisioningState}" \
  --output table

echo
echo "Azure hub to AVS peering (gateway transit):"
az network vnet peering show \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "azure-vnet" \
  --name "azure-to-avs" \
  --query "{Name:name, State:peeringState, Sync:peeringSyncLevel, AllowGatewayTransit:allowGatewayTransit, UseRemoteGateways:useRemoteGateways}" \
  --output table

echo
echo "AVS to Azure hub peering (uses remote gateway):"
az network vnet peering show \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "avs-vnet" \
  --name "avs-to-azure" \
  --query "{Name:name, State:peeringState, Sync:peeringSyncLevel, AllowGatewayTransit:allowGatewayTransit, UseRemoteGateways:useRemoteGateways}" \
  --output table

echo
echo "Simulated on-premises return prefixes (must include 172.16.1.0/24):"
az network local-gateway show \
  --resource-group "$RESOURCE_GROUP" \
  --name "azure-local-gateway" \
  --query "{Name:name, ProvisioningState:provisioningState, AddressPrefixes:join(', ', localNetworkAddressSpace.addressPrefixes)}" \
  --output table

echo
echo "avs-vm effective routes (confirm on-premises prefixes use VirtualNetworkGateway):"
az network nic show-effective-route-table \
  --resource-group "$RESOURCE_GROUP" \
  --name "avs-vm-nic" \
  --query "value[?source=='VirtualNetworkGateway'].{Source:source, State:state, AddressPrefixes:join(', ', addressPrefix), NextHopType:nextHopType}" \
  --output table

echo
echo "hub-vm FRRouting BGP summary:"
az vm run-command invoke \
  --resource-group "$RESOURCE_GROUP" \
  --name "hub-vm" \
  --command-id "RunShellScript" \
  --scripts "sudo vtysh -c 'show bgp ipv4 unicast summary'" \
  --query "value[0].message" \
  --output tsv

SCRIPT_END_EPOCH="$(date +%s)"
TOTAL_SECONDS=$((SCRIPT_END_EPOCH - SCRIPT_START_EPOCH))
TOTAL_HOURS=$((TOTAL_SECONDS / 3600))
TOTAL_MINUTES=$(((TOTAL_SECONDS % 3600) / 60))
TOTAL_REMAINING_SECONDS=$((TOTAL_SECONDS % 60))
DEPLOYMENT_OUTPUTS="$(az deployment group show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$DEPLOYMENT_NAME" \
  --query "[properties.outputs.bootDiagnosticsStorageAccountName.value, properties.outputs.logAnalyticsWorkspaceName.value]" \
  --output tsv)"
BOOT_DIAGNOSTICS_STORAGE_ACCOUNT="$(cut -f1 <<<"$DEPLOYMENT_OUTPUTS")"
LOG_ANALYTICS_WORKSPACE="$(cut -f2 <<<"$DEPLOYMENT_OUTPUTS")"

echo
echo "Total Duration:  ${TOTAL_HOURS}h ${TOTAL_MINUTES}m ${TOTAL_REMAINING_SECONDS}s"
echo "                 (${TOTAL_SECONDS} seconds)"
echo
echo "Gateway Deployment: Parallel (included in total duration)"
echo "=========================================="
echo
echo "Next Steps:"
echo "  1. Test connectivity from 192.168.1.0/24 to 10.70.1.0/24"
echo "  2. Test connectivity from 192.168.4.0/24 to 10.70.1.0/24"
echo "  3. Test VPN connectivity between sites"
echo "  4. Verify VM connectivity across VNets"
echo "  5. Monitor Azure Firewall metrics via Azure Portal"
echo "  6. View VM boot diagnostics in Azure Portal"
echo "     - Navigate to VM -> Boot diagnostics -> Screenshot/Serial log"
echo "  7. Monitor VM performance and health"
echo "  8. Verify UDR BGP propagation settings (should be 'No')"
echo "  9. Query Azure Firewall network-rule logs in Log Analytics"
echo " 10. Verify avs-vm routes to 192.168.0.0/22 and 192.168.4.0/22 use VirtualNetworkGateway"
echo " 11. Test connectivity between avs-vm and both on-premises VMs"
echo "=========================================="
echo
echo "VM Boot Diagnostics Access:"
echo "  - Azure Portal -> Virtual Machines -> [VM Name] -> Boot diagnostics"
echo "  - View screenshot of VM console"
echo "  - Download serial log for troubleshooting"
echo "  - Storage Account: $BOOT_DIAGNOSTICS_STORAGE_ACCOUNT"
echo "=========================================="
echo
echo "Azure Firewall Log Analytics:"
echo "  - Workspace: $LOG_ANALYTICS_WORKSPACE"
echo "  - Azure Portal -> Log Analytics workspaces -> $LOG_ANALYTICS_WORKSPACE -> Logs"
echo "  - Sample query:"
echo "      AZFWNetworkRule | where TimeGenerated > ago(1h) | order by TimeGenerated desc"
echo "  - Allow up to 10 minutes after first traffic for logs to appear."
echo "=========================================="
