#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="$SCRIPT_DIR/ZA-East-S2S-Fortigate.bicep"
FORTIGATE_TEMPLATE="$SCRIPT_DIR/fortigate-za-east-s2s.conf"

LOCATION="${AZURE_LOCATION:-southafricanorth}"
TENANT_ID_OVERRIDE="${AZURE_TENANT_ID:-}"
SUBSCRIPTION_ID_OVERRIDE="${AZURE_SUBSCRIPTION_ID:-}"
RESOURCE_GROUP_OVERRIDE="${AZURE_RESOURCE_GROUP:-}"

# On-premises FortiGate details.
ONPREM_GATEWAY_IP="${ONPREM_GATEWAY_IP:-169.0.216.146}"
ONPREM_ADDRESS_PREFIXES_JSON="${ONPREM_ADDRESS_PREFIXES_JSON:-[\"192.168.2.0/24\"]}"

# Pre-shared key. Override with S2S_SHARED_KEY to avoid keeping it on disk.
SHARED_KEY="${S2S_SHARED_KEY:-S2SPSK123!}"

usage() {
  cat <<'USAGE'
Usage: deploy-za-east-s2s-fortigate.sh [options]

Options:
  --tenant-id ID         Sign in to and deploy through this Microsoft Entra tenant.
  --subscription-id ID   Deploy to this Azure subscription.
  --resource-group NAME  Resource group that holds the ZA-East VPN gateway.
  --location NAME        Azure region (default: southafricanorth).
  -h, --help             Show this help.

Environment overrides:
  ONPREM_GATEWAY_IP            On-premises FortiGate public IP (default: 169.0.216.146).
  ONPREM_ADDRESS_PREFIXES_JSON JSON array of on-prem prefixes (default: ["192.168.2.0/24"]).
  S2S_SHARED_KEY               IPsec pre-shared key (default: the lab PSK).
USAGE
}

while (( $# > 0 )); do
  case "$1" in
    --tenant-id)
      (( $# >= 2 )) || { echo "--tenant-id requires a value." >&2; exit 2; }
      TENANT_ID_OVERRIDE="$2"; shift 2 ;;
    --subscription-id)
      (( $# >= 2 )) || { echo "--subscription-id requires a value." >&2; exit 2; }
      SUBSCRIPTION_ID_OVERRIDE="$2"; shift 2 ;;
    --resource-group)
      (( $# >= 2 )) || { echo "--resource-group requires a value." >&2; exit 2; }
      RESOURCE_GROUP_OVERRIDE="$2"; shift 2 ;;
    --location)
      (( $# >= 2 )) || { echo "--location requires a value." >&2; exit 2; }
      LOCATION="$2"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command '$1' is not installed or not in PATH." >&2
    exit 1
  fi
}

require_command az

if [[ -n "$TENANT_ID_OVERRIDE" ]]; then
  echo "Signing in to tenant $TENANT_ID_OVERRIDE..."
  az login --tenant "$TENANT_ID_OVERRIDE" >/dev/null
fi

if [[ -n "$SUBSCRIPTION_ID_OVERRIDE" ]]; then
  az account set --subscription "$SUBSCRIPTION_ID_OVERRIDE"
fi

if ! az account show >/dev/null 2>&1; then
  echo "No Azure CLI default context is set. Run 'az login' and 'az account set --subscription <ID>' first." >&2
  exit 1
fi

SUBSCRIPTION_NAME="$(az account show --query name --output tsv)"
SUBSCRIPTION_ID="$(az account show --query id --output tsv)"
TENANT_ID="$(az account show --query tenantId --output tsv)"

if [[ -n "$TENANT_ID_OVERRIDE" && "$TENANT_ID" != "$TENANT_ID_OVERRIDE" ]]; then
  echo "Subscription '$SUBSCRIPTION_ID' belongs to tenant '$TENANT_ID', not '$TENANT_ID_OVERRIDE'." >&2
  exit 1
fi

DEFAULT_RESOURCE_GROUP="za-east-${LOCATION}"
if [[ -n "$RESOURCE_GROUP_OVERRIDE" ]]; then
  RESOURCE_GROUP_NAME="$RESOURCE_GROUP_OVERRIDE"
else
  read -r -p "Resource group [$DEFAULT_RESOURCE_GROUP]: " RESOURCE_GROUP_NAME
  RESOURCE_GROUP_NAME="${RESOURCE_GROUP_NAME:-$DEFAULT_RESOURCE_GROUP}"
fi

VPN_GATEWAY_NAME="za-east-${LOCATION}-vpngw"
VPN_GATEWAY_PUBLIC_IP_NAME="za-east-${LOCATION}-vpngw-pip"
LOCAL_NETWORK_GATEWAY_NAME="za-east-${LOCATION}-fortigate-lng"
CONNECTION_NAME="za-east-${LOCATION}-to-fortigate"

# The VPN gateway must exist and be provisioned before a connection can attach.
GATEWAY_STATE="$(az network vnet-gateway show \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --name "$VPN_GATEWAY_NAME" \
  --subscription "$SUBSCRIPTION_ID" \
  --query provisioningState \
  --output tsv 2>/dev/null || true)"

if [[ "$GATEWAY_STATE" != "Succeeded" ]]; then
  echo "VPN gateway '$VPN_GATEWAY_NAME' is not ready (state: '${GATEWAY_STATE:-not found}')." >&2
  echo "Deploy the gateway with deploy-za-east-firewall-policy-udrs.sh before creating the tunnel." >&2
  exit 1
fi

AZURE_VPNGW_PUBLIC_IP="$(az network public-ip show \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --name "$VPN_GATEWAY_PUBLIC_IP_NAME" \
  --subscription "$SUBSCRIPTION_ID" \
  --query ipAddress \
  --output tsv)"

echo
echo "Deployment summary:"
echo "  Subscription:        $SUBSCRIPTION_NAME ($SUBSCRIPTION_ID)"
echo "  Tenant:              $TENANT_ID"
echo "  Resource group:      $RESOURCE_GROUP_NAME"
echo "  Location:            $LOCATION"
echo "  VPN gateway:         $VPN_GATEWAY_NAME"
echo "  Azure gateway IP:    $AZURE_VPNGW_PUBLIC_IP"
echo "  Local net gateway:   $LOCAL_NETWORK_GATEWAY_NAME"
echo "  Connection:          $CONNECTION_NAME"
echo "  On-prem gateway IP:  $ONPREM_GATEWAY_IP"
echo "  On-prem prefixes:    $ONPREM_ADDRESS_PREFIXES_JSON"
echo

DEPLOYMENT_NAME="za-east-s2s-fortigate-$(date -u +%Y%m%d-%H%M%S)"
PARAMETERS=(
  "location=$LOCATION"
  "vpnGatewayName=$VPN_GATEWAY_NAME"
  "localNetworkGatewayName=$LOCAL_NETWORK_GATEWAY_NAME"
  "onPremisesGatewayIpAddress=$ONPREM_GATEWAY_IP"
  "onPremisesAddressPrefixes=$ONPREM_ADDRESS_PREFIXES_JSON"
  "connectionName=$CONNECTION_NAME"
  "sharedKey=$SHARED_KEY"
)

echo "Building Bicep template..."
az bicep build --file "$TEMPLATE_FILE" --stdout >/dev/null

echo "Running resource group deployment validation..."
az deployment group validate \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --name "$DEPLOYMENT_NAME" \
  --template-file "$TEMPLATE_FILE" \
  --parameters "${PARAMETERS[@]}" \
  --subscription "$SUBSCRIPTION_ID" \
  --output table

echo
echo "Validation succeeded. Starting deployment..."
az deployment group create \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --name "$DEPLOYMENT_NAME" \
  --template-file "$TEMPLATE_FILE" \
  --parameters "${PARAMETERS[@]}" \
  --subscription "$SUBSCRIPTION_ID" \
  --query 'properties.outputs' \
  --output json

# Render a ready-to-paste FortiGate script with the live Azure gateway IP.
if [[ -f "$FORTIGATE_TEMPLATE" ]]; then
  RENDERED_FILE="$SCRIPT_DIR/fortigate-za-east-s2s.rendered.conf"
  sed "s|__AZURE_VPNGW_PUBLIC_IP__|$AZURE_VPNGW_PUBLIC_IP|g" "$FORTIGATE_TEMPLATE" > "$RENDERED_FILE"
  echo
  echo "FortiGate script rendered with Azure gateway IP $AZURE_VPNGW_PUBLIC_IP:"
  echo "  $RENDERED_FILE"
fi

echo
echo "Next steps on the FortiGate:"
echo "  1. Set the WAN and LAN interface names in the FortiGate script."
echo "  2. Point 'set remote-gw' at $AZURE_VPNGW_PUBLIC_IP (already rendered)."
echo "  3. Paste the CLI section into the FortiGate to bring up the tunnel."
