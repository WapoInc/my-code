#!/usr/bin/env bash

set -euo pipefail

# =============================================================================
# ZA-East site-to-site VPN deployment (portable runner)
# =============================================================================
# Creates the Azure side of an IPsec site-to-site tunnel to an on-premises
# FortiGate, then renders a ready-to-paste FortiGate config. Deploys into
# whatever subscription your Azure CLI is logged in to. It drives one
# resource-group-scope Bicep template (ZA-East-S2S-Fortigate.bicep).
#
# Components created / managed:
#   - Local network gateway   represents the on-prem site: the FortiGate public
#                             IP plus the on-prem address prefixes behind it.
#   - Connection              IPsec/IKEv2 link between the existing Azure VPN
#                             gateway and the local network gateway, secured by
#                             the pre-shared key. Uses Azure's default IPsec
#                             policy (matches AES256/SHA256/DHGroup2 on the FGT).
#   - Rendered FortiGate conf  fortigate-za-east-s2s.rendered.conf, produced by
#                             substituting the live Azure gateway public IP into
#                             fortigate-za-east-s2s.conf.
#
# If the Azure VPN gateway is missing, this script creates it (Basic/RouteBased)
# in the hub's GatewaySubnet with a zoned Standard public IP. It also creates the
# GatewaySubnet (10.20.0.0/24) and a VM subnet Subnet-1 (10.20.2.0/25) if absent.
# The hub VNet must already exist (deploy-za-east-firewall-policy-udrs.sh).
#
# Prerequisites: az CLI and an authenticated Azure context (az login).
# On-prem IP, prefixes, and the PSK come from flags or the environment overrides
# below (set S2S_SHARED_KEY to keep the key out of this file).
# =============================================================================

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

# ---- Verify tools and establish the Azure context ----
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
HUB_VNET_NAME="za-east-${LOCATION}-vnet"
AZURE_FIREWALL_NAME="AzFW-ZA-East-vDC"

# ---- Ensure the hub VNet has the required subnets ----
if ! az network vnet show \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --name "$HUB_VNET_NAME" \
  --subscription "$SUBSCRIPTION_ID" >/dev/null 2>&1; then
  echo "Hub VNet '$HUB_VNET_NAME' not found. Run deploy-za-east-firewall-policy-udrs.sh first to build the hub network." >&2
  exit 1
fi

if ! az network vnet subnet show \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --vnet-name "$HUB_VNET_NAME" \
  --name GatewaySubnet \
  --subscription "$SUBSCRIPTION_ID" >/dev/null 2>&1; then
  echo "Creating GatewaySubnet (10.20.0.0/24) in '$HUB_VNET_NAME'..."
  az network vnet subnet create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --vnet-name "$HUB_VNET_NAME" \
    --name GatewaySubnet \
    --address-prefixes 10.20.0.0/24 \
    --subscription "$SUBSCRIPTION_ID" \
    --output none
fi

if ! az network vnet subnet show \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --vnet-name "$HUB_VNET_NAME" \
  --name Subnet-1 \
  --subscription "$SUBSCRIPTION_ID" >/dev/null 2>&1; then
  echo "Creating VM subnet Subnet-1 (10.20.2.0/25) in '$HUB_VNET_NAME'..."
  az network vnet subnet create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --vnet-name "$HUB_VNET_NAME" \
    --name Subnet-1 \
    --address-prefixes 10.20.2.0/25 \
    --subscription "$SUBSCRIPTION_ID" \
    --output none
fi

# ---- Ensure a healthy VPN gateway exists (create it if missing) ----
# A connection can only attach to a Succeeded gateway. If none exists we create
# a Basic route-based gateway in the hub's GatewaySubnet with a zoned Standard PIP.
GATEWAY_STATE="$(az network vnet-gateway show \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --name "$VPN_GATEWAY_NAME" \
  --subscription "$SUBSCRIPTION_ID" \
  --query provisioningState \
  --output tsv 2>/dev/null || true)"

if [[ "$GATEWAY_STATE" == "Succeeded" ]]; then
  : # Gateway already provisioned; nothing to do.
elif [[ -z "$GATEWAY_STATE" ]]; then
  # No gateway. GatewaySubnet is ensured above.
  # A Basic gateway needs a Standard, zone-redundant public IP.
  if ! az network public-ip show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$VPN_GATEWAY_PUBLIC_IP_NAME" \
    --subscription "$SUBSCRIPTION_ID" >/dev/null 2>&1; then
    echo "Creating VPN gateway public IP '$VPN_GATEWAY_PUBLIC_IP_NAME'..."
    az network public-ip create \
      --resource-group "$RESOURCE_GROUP_NAME" \
      --name "$VPN_GATEWAY_PUBLIC_IP_NAME" \
      --sku Standard \
      --allocation-method Static \
      --zone 1 2 3 \
      --subscription "$SUBSCRIPTION_ID" \
      --output none
  fi

  echo "Creating VPN gateway '$VPN_GATEWAY_NAME' (Basic/RouteBased). This can take 30-45 minutes..."
  az network vnet-gateway create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$VPN_GATEWAY_NAME" \
    --vnet "$HUB_VNET_NAME" \
    --public-ip-address "$VPN_GATEWAY_PUBLIC_IP_NAME" \
    --gateway-type Vpn \
    --vpn-type RouteBased \
    --sku Basic \
    --subscription "$SUBSCRIPTION_ID" \
    --output none

  GATEWAY_STATE="$(az network vnet-gateway show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$VPN_GATEWAY_NAME" \
    --subscription "$SUBSCRIPTION_ID" \
    --query provisioningState \
    --output tsv)"
  if [[ "$GATEWAY_STATE" != "Succeeded" ]]; then
    echo "VPN gateway creation did not reach 'Succeeded' (state: '$GATEWAY_STATE')." >&2
    exit 1
  fi
else
  echo "VPN gateway '$VPN_GATEWAY_NAME' is in state '$GATEWAY_STATE'. Wait for it to finish, then rerun this script." >&2
  exit 1
fi

# ---- Wait for the VPN gateway public IP, then use it as the tunnel endpoint ----
echo "Waiting for the VPN gateway public IP address to be assigned..."
AZURE_VPNGW_PUBLIC_IP=""
for _ in $(seq 1 30); do
  AZURE_VPNGW_PUBLIC_IP="$(az network public-ip show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$VPN_GATEWAY_PUBLIC_IP_NAME" \
    --subscription "$SUBSCRIPTION_ID" \
    --query ipAddress \
    --output tsv 2>/dev/null || true)"
  [[ -n "$AZURE_VPNGW_PUBLIC_IP" ]] && break
  sleep 10
done

if [[ -z "$AZURE_VPNGW_PUBLIC_IP" ]]; then
  echo "The VPN gateway public IP '$VPN_GATEWAY_PUBLIC_IP_NAME' has no address assigned yet." >&2
  echo "Wait for the gateway to finish provisioning, then rerun this script." >&2
  exit 1
fi
echo "VPN gateway public IP (tunnel endpoint): $AZURE_VPNGW_PUBLIC_IP"

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

# ---- Build parameters, then compile, validate and deploy the template ----
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

# ---- Summary of the deployed resources ----
echo
echo "Deployed resource settings:"
echo "  Region:                 $LOCATION"
echo "  Resource group:         $RESOURCE_GROUP_NAME"
echo "  Hub VNet:               $HUB_VNET_NAME"
echo "  VPN gateway:            $VPN_GATEWAY_NAME"
echo "  VPN gateway public IP:  $AZURE_VPNGW_PUBLIC_IP"
echo "  Azure Firewall:         $AZURE_FIREWALL_NAME"
echo "  Local network gateway:  $LOCAL_NETWORK_GATEWAY_NAME"
echo "  IPsec connection:       $CONNECTION_NAME"

echo
echo "Next steps on the FortiGate:"
echo "  1. Set the WAN and LAN interface names in the FortiGate script."
echo "  2. Point 'set remote-gw' at $AZURE_VPNGW_PUBLIC_IP (already rendered)."
echo "  3. Paste the CLI section into the FortiGate to bring up the tunnel."
