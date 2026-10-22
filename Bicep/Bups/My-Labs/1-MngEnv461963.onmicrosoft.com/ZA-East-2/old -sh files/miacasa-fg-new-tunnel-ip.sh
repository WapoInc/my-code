#!/usr/bin/env bash

set -euo pipefail

readonly SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-0cfd0d2a-2b38-4c93-ba14-cf79185bc683}"
readonly RESOURCE_GROUP_NAME="${AZURE_RESOURCE_GROUP:-za-east-southafricanorth}"
readonly VPN_GATEWAY_SKU="${AZURE_VPN_GATEWAY_SKU:-VpnGw1AZ}"
readonly VPN_GATEWAY_PUBLIC_IP_NAME="${AZURE_VPN_GATEWAY_PUBLIC_IP_NAME:-za-east-VPN-Gateway-southafricanorth-${VPN_GATEWAY_SKU}-zones123-pip}"
readonly FORTIGATE_TUNNEL_NAME="${FORTIGATE_TUNNEL_NAME:-ZA-East-vDC}"
readonly FORTIGATE_USERNAME="${FORTIGATE_USERNAME:-admin}"
readonly IPSEC_PSK='S2SPSK123!'
readonly FORTIGATE_BGP_ASN='65521'

usage() {
  echo "Usage: $0 [fortigate-management-ip-or-hostname]" >&2
  echo >&2
  echo "Optional environment variables:" >&2
  echo "  AZURE_SUBSCRIPTION_ID" >&2
  echo "  AZURE_RESOURCE_GROUP" >&2
  echo "  AZURE_VPN_GATEWAY_SKU" >&2
  echo "  AZURE_VPN_GATEWAY_PUBLIC_IP_NAME" >&2
  echo "  FORTIGATE_TUNNEL_NAME" >&2
  echo "  FORTIGATE_USERNAME" >&2
}

if [[ $# -gt 1 ]]; then
  usage
  exit 2
fi

if ! command -v az >/dev/null 2>&1; then
  echo "Azure CLI is not installed or is not in PATH." >&2
  exit 1
fi

if ! command -v ssh >/dev/null 2>&1; then
  echo "SSH is not installed or is not in PATH." >&2
  exit 1
fi

readonly FORTIGATE_HOST="${1:-192.168.2.1}"

azure_vpn_gateway_ip="$(az network public-ip show \
  --subscription "$SUBSCRIPTION_ID" \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --name "$VPN_GATEWAY_PUBLIC_IP_NAME" \
  --query ipAddress \
  --output tsv)"

if [[ -z "$azure_vpn_gateway_ip" || "$azure_vpn_gateway_ip" == "null" ]]; then
  echo "The Azure VPN gateway public IP has not been allocated." >&2
  exit 1
fi

if [[ ! "$azure_vpn_gateway_ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
  echo "Azure returned an invalid VPN gateway public IP: $azure_vpn_gateway_ip" >&2
  exit 1
fi

echo "Updating FortiGate tunnel '$FORTIGATE_TUNNEL_NAME' to remote gateway $azure_vpn_gateway_ip..."

ssh -T "${FORTIGATE_USERNAME}@${FORTIGATE_HOST}" <<FORTIGATE_CLI
config vpn ipsec phase1-interface
    edit "${FORTIGATE_TUNNEL_NAME}"
        set remote-gw ${azure_vpn_gateway_ip}
        set psksecret "${IPSEC_PSK}"
    next
end
config router bgp
  set as ${FORTIGATE_BGP_ASN}
end
FORTIGATE_CLI

echo "FortiGate tunnel '$FORTIGATE_TUNNEL_NAME' now uses Azure gateway $azure_vpn_gateway_ip."
echo "FortiGate BGP ASN is now $FORTIGATE_BGP_ASN."
