#!/usr/bin/env bash
#
# Deploys the hub + 3 spokes lab (VNets, peerings, 4 Ubuntu VMs,
# private DNS zone with an A record per VM) into South Africa North.
# Includes an ExpressRoute gateway and circuit connection, with spoke gateway transit.
#
# Usage:
#   ./deploy-dns-resolv.sh              # deploy
#   ./deploy-dns-resolv.sh --what-if    # preview changes only
#   ./deploy-dns-resolv.sh --validate   # validate template only
#
# Overridable via environment variables:
#   SUBSCRIPTION_ID, RG, LOCATION, ADMIN_USERNAME, ADMIN_PASSWORD,
#   PRIVATE_DNS_ZONE_NAME, TEMPLATE_FILE, EXPRESS_ROUTE_CIRCUIT_ID,
#   EXPRESS_ROUTE_GATEWAY_SKU, GATEWAY_SUBNET_PREFIX
# The target subscription must have access to the circuit in the same subscription.
# GatewaySubnet has no NSG. FortiGate policies are in fortigate-er-policies.conf.
# On-premises routing/BGP must advertise 172.22.1.0/24 and learn the four Azure /24s.
# Private DNS resolution from on-premises requires a resolver/forwarder (not deployed).
#
set -euo pipefail

SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-}"
RG="${RG:-sa-north-hub-spokes-rg}"
LOCATION="${LOCATION:-southafricanorth}"
ADMIN_USERNAME="${ADMIN_USERNAME:-rootadmin}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-P@ssw0rd123!}"
PRIVATE_DNS_ZONE_NAME="${PRIVATE_DNS_ZONE_NAME:-lab.internal}"
EXPRESS_ROUTE_CIRCUIT_ID="${EXPRESS_ROUTE_CIRCUIT_ID:-/subscriptions/0cfd0d2a-2b38-4c93-ba14-cf79185bc683/resourceGroups/ER-LTSA-rg/providers/Microsoft.Network/expressRouteCircuits/ER-LIT-ZAN}"
EXPRESS_ROUTE_GATEWAY_SKU="${EXPRESS_ROUTE_GATEWAY_SKU:-ErGw1AZ}"
GATEWAY_SUBNET_PREFIX="${GATEWAY_SUBNET_PREFIX:-10.30.0.128/27}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="${TEMPLATE_FILE:-$SCRIPT_DIR/main.bicep}"
DEPLOYMENT_NAME="hub-spokes-$(date -u +%Y%m%d-%H%M%S)"

MODE="deploy"
case "${1:-}" in
  --what-if)  MODE="what-if" ;;
  --validate) MODE="validate" ;;
  "")         ;;
  *) echo "Unknown argument: $1" >&2; exit 1 ;;
esac

log()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

log "Preflight checks"
command -v az >/dev/null 2>&1 || die "Azure CLI not found. https://aka.ms/azure-cli"
az bicep version >/dev/null 2>&1 || { log "Installing Bicep CLI..."; az bicep install; }
[[ -f "$TEMPLATE_FILE" ]] || die "Template not found: $TEMPLATE_FILE"
az account show >/dev/null 2>&1 || die "Not logged in. Run 'az login' first."

if [[ -n "$SUBSCRIPTION_ID" ]]; then
  az account set --subscription "$SUBSCRIPTION_ID"
fi
echo "Subscription : $(az account show --query name -o tsv)"
echo "Resource grp : $RG ($LOCATION)"
echo "DNS zone     : $PRIVATE_DNS_ZONE_NAME"
echo "ER circuit   : $EXPRESS_ROUTE_CIRCUIT_ID"
echo "ER gateway   : $EXPRESS_ROUTE_GATEWAY_SKU (GatewaySubnet $GATEWAY_SUBNET_PREFIX)"

log "Ensuring resource group '$RG'"
az group create -n "$RG" -l "$LOCATION" -o none

COMMON_ARGS=(
  --resource-group "$RG"
  --template-file "$TEMPLATE_FILE"
  --parameters location="$LOCATION"
               adminUsername="$ADMIN_USERNAME"
               adminPassword="$ADMIN_PASSWORD"
               privateDnsZoneName="$PRIVATE_DNS_ZONE_NAME"
               expressRouteCircuitId="$EXPRESS_ROUTE_CIRCUIT_ID"
               expressRouteGatewaySku="$EXPRESS_ROUTE_GATEWAY_SKU"
               gatewaySubnetPrefix="$GATEWAY_SUBNET_PREFIX"
)

case "$MODE" in
  validate)
    log "Validating deployment"
    az deployment group validate "${COMMON_ARGS[@]}" -o table
    exit 0
    ;;
  what-if)
    log "Running what-if (no changes applied)"
    az deployment group what-if "${COMMON_ARGS[@]}"
    exit 0
    ;;
esac

log "Deploying '$DEPLOYMENT_NAME'"
az deployment group create --name "$DEPLOYMENT_NAME" "${COMMON_ARGS[@]}" -o none

log "Deployment complete"
az deployment group show -g "$RG" -n "$DEPLOYMENT_NAME" \
  --query properties.outputs -o json
