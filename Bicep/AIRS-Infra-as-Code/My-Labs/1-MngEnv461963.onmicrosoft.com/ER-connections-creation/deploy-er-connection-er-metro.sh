#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./deploy-er-connection-er-metro.sh              # preview with what-if
#   ./deploy-er-connection-er-metro.sh --validate   # validate only
#   ./deploy-er-connection-er-metro.sh --deploy     # create or update connection

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="${TEMPLATE_FILE:-$SCRIPT_DIR/deploy-er-metro-connection.bicep}"

SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-0cfd0d2a-2b38-4c93-ba14-cf79185bc683}"
RESOURCE_GROUP="${RESOURCE_GROUP:-ER-LTSA-rg}"
LOCATION="${LOCATION:-southafricanorth}"
GATEWAY_NAME="${GATEWAY_NAME:-ER-GateWay-southafricanorth-Standard}"
GATEWAY_RESOURCE_GROUP="${GATEWAY_RESOURCE_GROUP:-southafricanorth-region}"
CONNECTION_NAME="${CONNECTION_NAME:-ER-Metro-Conn-to-ER-GateWay-southafricanorth-Standard}"
CIRCUIT_RESOURCE_ID="${CIRCUIT_RESOURCE_ID:-/subscriptions/0cfd0d2a-2b38-4c93-ba14-cf79185bc683/resourceGroups/ER-LTSA-rg/providers/Microsoft.Network/expressRouteCircuits/ER-Metro}"
ROUTING_WEIGHT="${ROUTING_WEIGHT:-0}"
DEPLOYMENT_NAME="${DEPLOYMENT_NAME:-deploy-er-metro-connection}"

MODE="${1:---what-if}"
case "$MODE" in
  --validate | --what-if | --deploy) ;;
  *)
    printf 'Usage: %s [--validate|--what-if|--deploy]\n' "${0##*/}" >&2
    exit 2
    ;;
esac

command -v az >/dev/null 2>&1 || {
  echo 'Azure CLI is required but was not found.' >&2
  exit 1
}

[[ -f "$TEMPLATE_FILE" ]] || {
  echo "Bicep template not found: $TEMPLATE_FILE" >&2
  exit 1
}

az account show --output none 2>/dev/null || {
  echo "Sign in first with 'az login'." >&2
  exit 1
}

az account set --subscription "$SUBSCRIPTION_ID"

GATEWAY_LOCATION="$(az network vnet-gateway show \
  --resource-group "$GATEWAY_RESOURCE_GROUP" \
  --name "$GATEWAY_NAME" \
  --query location \
  --output tsv 2>/dev/null)" || {
  echo "ExpressRoute gateway '$GATEWAY_NAME' was not found in '$GATEWAY_RESOURCE_GROUP'." >&2
  exit 1
}

CIRCUIT_LOCATION="$(az resource show \
  --ids "$CIRCUIT_RESOURCE_ID" \
  --query location \
  --output tsv 2>/dev/null)" || {
  echo "ExpressRoute circuit was not found: $CIRCUIT_RESOURCE_ID" >&2
  exit 1
}

if [[ "$GATEWAY_LOCATION" != "$LOCATION" || "$CIRCUIT_LOCATION" != "$LOCATION" ]]; then
  echo "Gateway, circuit, and connection must use the same Azure region ('$LOCATION')." >&2
  echo "Gateway region: $GATEWAY_LOCATION; circuit region: $CIRCUIT_LOCATION" >&2
  exit 1
fi

COMMON_ARGS=(
  --name "$DEPLOYMENT_NAME"
  --resource-group "$RESOURCE_GROUP"
  --template-file "$TEMPLATE_FILE"
  --parameters
  "location=$LOCATION"
  "gatewayName=$GATEWAY_NAME"
  "gatewayResourceGroupName=$GATEWAY_RESOURCE_GROUP"
  "connectionName=$CONNECTION_NAME"
  "circuitResourceId=$CIRCUIT_RESOURCE_ID"
  "routingWeight=$ROUTING_WEIGHT"
)

echo "Subscription : $(az account show --query name --output tsv)"
echo "Resource group: $RESOURCE_GROUP"
echo "Gateway       : $GATEWAY_NAME ($GATEWAY_RESOURCE_GROUP)"
echo "Circuit       : $CIRCUIT_RESOURCE_ID"
echo "Connection    : $CONNECTION_NAME"

case "$MODE" in
  --validate)
    az deployment group validate "${COMMON_ARGS[@]}" \
      --query properties.provisioningState --output tsv
    ;;
  --what-if)
    az deployment group what-if "${COMMON_ARGS[@]}" \
      --result-format FullResourcePayloads
    ;;
  --deploy)
    az deployment group create "${COMMON_ARGS[@]}" \
      --query 'properties.outputs.{Connection:connectionName.value,ConnectionId:connectionId.value,GatewayId:gatewayId.value,CircuitId:circuitId.value}' \
      --output table
    ;;
esac