#!/usr/bin/env bash
# #####-change back to AES from 3DES-------------------------------------------------------------------------------
# Script: setup-hybrid-network.sh
# Purpose: Create a simulated hybrid network in Azure (single RG version):
#          - "Hub" virtual network with VPN gateway
#          - "On-prem (simulated)" virtual network with its own VPN gateway
#          - Local network gateways referencing each other's public IP + address space
#          - Site-to-site IPsec (IKEv2) connections (bi-directional)
#          - WAIT until gateways provision and tunnels show Connected
# vmr Sandbox ##
#
# NOTE: Using a single resource group per user request (although
#       in production, separating environments or roles can aid RBAC & lifecycle).
#
# Prerequisites:
#   az login && az account set -s <subscription-id>
#   Azure CLI >= 2.55
#
# -----------------------------------------------------------------------------
set -euo pipefail

# ---------------- User Adjustable Variables ----------------------------------
ENVIRONMENT="dev"
REGION="southafricanorth"   # Requested region

# Address spaces (must NOT overlap)
HUB_VNET_CIDR="10.10.0.0/16"
HUB_WORKLOAD_SUBNET_CIDR="10.10.1.0/24"
HUB_GW_SUBNET_CIDR="10.10.255.0/27"

ONPREM_VNET_CIDR="10.20.0.0/16"
ONPREM_WORKLOAD_SUBNET_CIDR="10.20.1.0/24"
ONPREM_GW_SUBNET_CIDR="10.20.255.0/27"

# Single Resource Group
RG_NAME="rg-network-hybrid-${ENVIRONMENT}-san"

# VNet Names
HUB_VNET_NAME="vnet-hub-${ENVIRONMENT}-san"
ONPREM_VNET_NAME="vnet-onprem-sim-${ENVIRONMENT}-san"

# Subnets
HUB_SUBNET_NAME="snet-workload"
ONPREM_SUBNET_NAME="snet-onprem-workload"
GATEWAY_SUBNET_NAME="GatewaySubnet"  # Must be exactly this for VPN Gateway

# Public IPs
HUB_PIP_NAME="pip-vgw-hub-${ENVIRONMENT}-san"
ONPREM_PIP_NAME="pip-vgw-onprem-sim-${ENVIRONMENT}-san"

# VPN Gateways
HUB_VGW_NAME="vgw-hub-${ENVIRONMENT}-san"
ONPREM_VGW_NAME="vgw-onprem-sim-${ENVIRONMENT}-san"

# Local Network Gateways
LNG_ONPREM_NAME="lng-onprem-${ENVIRONMENT}-san"
LNG_HUB_NAME="lng-hub-${ENVIRONMENT}-san"

# Connections
CONN_HUB_TO_ONPREM="conn-hub-to-onprem-${ENVIRONMENT}-san"
CONN_ONPREM_TO_HUB="conn-onprem-to-hub-${ENVIRONMENT}-san"

# VPN Gateway SKU
VPN_GW_SKU="VpnGw1AZ"

# Shared key; allow override via env
SHARED_KEY="${SHARED_KEY:-$(openssl rand -base64 32 | tr -d '=+/')}"

# Strong IPsec policy (optional override of defaults)
IKE_ENC="AES256"
IKE_INT="SHA256"
IPSEC_ENC="AES256"
IPSEC_INT="SHA256"
DH_GROUP="DHGroup14"
PFS_GROUP="PFS14"
SA_LIFETIME_SECONDS="3600"
SA_MAX_KB="102400000"

# Tags
TAGS="environment=${ENVIRONMENT} cost-center=net-lab owner=$(whoami) workload=hybrid-network compliance=internal region=${REGION}"

# Poll intervals and timeouts
GATEWAY_POLL_SECONDS=90
CONNECTION_POLL_SECONDS=30
CONNECTION_TIMEOUT_SECONDS=1800   # 30 minutes

# ---------------- Functions --------------------------------------------------

header () {
  echo -e "\n====================================================================="
  echo "== $1"
  echo "=====================================================================\n"
}

ensure_group () {
  local rg=$1 region=$2
  if ! az group show --name "$rg" &>/dev/null; then
    echo "Creating resource group $rg in $region"
    az group create --name "$rg" --location "$region" --tags $TAGS >/dev/null
  else
    echo "Resource group $rg exists; updating tags"
    az group update --name "$rg" --set \
      tags.environment="$ENVIRONMENT" \
      tags.cost-center="net-lab" \
      tags.owner="$(whoami)" \
      tags.workload="hybrid-network" \
      tags.compliance="internal" \
      tags.region="$REGION" >/dev/null
  fi
}

create_vnet_and_subnets () {
  local rg=$1 vnet=$2 address_space=$3 workload_subnet_name=$4 workload_subnet_cidr=$5 gw_subnet_cidr=$6
  if ! az network vnet show -g "$rg" -n "$vnet" &>/dev/null; then
    echo "Creating VNet $vnet"
    az network vnet create -g "$rg" -n "$vnet" \
      --address-prefixes "$address_space" \
      --subnet-name "$workload_subnet_name" \
      --subnet-prefixes "$workload_subnet_cidr" \
      --tags $TAGS >/dev/null
  else
    echo "VNet $vnet already exists."
  fi
  if ! az network vnet subnet show -g "$rg" --vnet-name "$vnet" -n GatewaySubnet &>/dev/null; then
    echo "Adding GatewaySubnet to $vnet"
    az network vnet subnet create -g "$rg" --vnet-name "$vnet" -n GatewaySubnet \
      --address-prefixes "$gw_subnet_cidr" >/dev/null
  fi
}

create_public_ip () {
  local rg=$1 name=$2
  if ! az network public-ip show -g "$rg" -n "$name" &>/dev/null; then
    echo "Creating Standard static Public IP $name"
    az network public-ip create -g "$rg" -n "$name" \
      --version IPv4 --sku Standard --allocation-method Static \
      --tags $TAGS >/dev/null
  else
    echo "Public IP $name exists."
  fi
}

create_vpn_gateway () {
  local rg=$1 vnet=$2 pip=$3 vgw=$4 asn=$5
  if ! az network vnet-gateway show -g "$rg" -n "$vgw" &>/dev/null; then
    echo "Provisioning VPN gateway $vgw (may take 30–45 minutes)..."
    az network vnet-gateway create \
      -g "$rg" -n "$vgw" \
      --public-ip-addresses "$pip" \
      --vnet "$vnet" \
      --gateway-type Vpn \
      --vpn-type RouteBased \
      --sku "$VPN_GW_SKU" \
      --asn "$asn" \
      --tags $TAGS >/dev/null
  else
    echo "VPN gateway $vgw exists."
  fi
}

wait_for_gateway () {
  local rg=$1 vgw=$2
  echo "Waiting for VPN gateway $vgw provisioningState=Succeeded ..."
  local state=""
  while true; do
    state=$(az network vnet-gateway show -g "$rg" -n "$vgw" --query provisioningState -o tsv 2>/dev/null || echo "Unknown")
    echo "$(date '+%H:%M:%S') - $vgw state: $state"
    [[ "$state" == "Succeeded" ]] && break
    sleep "$GATEWAY_POLL_SECONDS"
  done
}

get_public_ip_address () {
  local rg=$1 name=$2
  az network public-ip show -g "$rg" -n "$name" --query ipAddress -o tsv
}

create_local_network_gateway () {
  local rg=$1 name=$2 ip=$3 prefix=$4
  if ! az network local-gateway show -g "$rg" -n "$name" &>/dev/null; then
    echo "Creating Local Network Gateway $name -> $ip ($prefix)"
    az network local-gateway create -g "$rg" -n "$name" \
      --gateway-ip-address "$ip" \
      --local-address-prefixes "$prefix" \
      --tags $TAGS >/dev/null
  else
    echo "Local Network Gateway $name exists."
  fi
}

create_connection () {
  local rg=$1 conn=$2 vgw=$3 lng=$4
  if ! az network vpn-connection show -g "$rg" -n "$conn" &>/dev/null; then
    echo "Creating VPN Connection $conn"
    az network vpn-connection create \
      -g "$rg" -n "$conn" \
      --vnet-gateway1 "$vgw" \
      --local-gateway2 "$lng" \
      --shared-key "$SHARED_KEY" \
      --enable-bgp false \
      --ipsec-policy \
        ike-encryption "$IKE_ENC" \
        ike-integrity "$IKE_INT" \
        ipsec-encryption "$IPSEC_ENC" \
        ipsec-integrity "$IPSEC_INT" \
        dh-group "$DH_GROUP" \
        pfs-group "$PFS_GROUP" \
        sa-lifetime "$SA_LIFETIME_SECONDS" \
        sa-max-size "$SA_MAX_KB" \
      --tags $TAGS >/dev/null
  else
    echo "VPN Connection $conn exists."
  fi
}

wait_for_connection () {
  local rg=$1 conn=$2
  local start_ts
  start_ts=$(date +%s)
  echo "Waiting for VPN connection $conn to reach Connected..."
  while true; do
    local status ingress egress
    status=$(az network vpn-connection show -g "$rg" -n "$conn" --query connectionStatus -o tsv 2>/dev/null || echo "Unknown")
    ingress=$(az network vpn-connection show -g "$rg" -n "$conn" --query ingressBytesTransferred -o tsv 2>/dev/null || echo "0")
    egress=$(az network vpn-connection show -g "$rg" -n "$conn" --query egressBytesTransferred -o tsv 2>/dev/null || echo "0")
    echo "$(date '+%H:%M:%S') - $conn status: $status (ingress=${ingress}B egress=${egress}B)"
    if [[ "$status" == "Connected" ]]; then
      echo "$conn is Connected."
      break
    fi
    local now_ts
    now_ts=$(date +%s)
    if (( now_ts - start_ts > CONNECTION_TIMEOUT_SECONDS )); then
      echo "ERROR: Timeout waiting for $conn (>${CONNECTION_TIMEOUT_SECONDS}s)."
      exit 1
    fi
    sleep "$CONNECTION_POLL_SECONDS"
  done
}

# ---------------- Execution --------------------------------------------------

header "Hybrid Network Deployment (Single RG, Region: $REGION)"

echo "Pre-Shared Key is hidden. To reveal: echo \$SHARED_KEY"

header "Resource Group"
ensure_group "$RG_NAME" "$REGION"

header "Virtual Networks & Subnets"
create_vnet_and_subnets "$RG_NAME" "$HUB_VNET_NAME" "$HUB_VNET_CIDR" "$HUB_SUBNET_NAME" "$HUB_WORKLOAD_SUBNET_CIDR" "$HUB_GW_SUBNET_CIDR"
create_vnet_and_subnets "$RG_NAME" "$ONPREM_VNET_NAME" "$ONPREM_VNET_CIDR" "$ONPREM_SUBNET_NAME" "$ONPREM_WORKLOAD_SUBNET_CIDR" "$ONPREM_GW_SUBNET_CIDR"

header "Public IPs"
create_public_ip "$RG_NAME" "$HUB_PIP_NAME"
create_public_ip "$RG_NAME" "$ONPREM_PIP_NAME"

HUB_PIP_IP=$(get_public_ip_address "$RG_NAME" "$HUB_PIP_NAME")
ONPREM_PIP_IP=$(get_public_ip_address "$RG_NAME" "$ONPREM_PIP_NAME")
echo "Hub Gateway Public IP: $HUB_PIP_IP"
echo "On-Prem Sim Gateway Public IP: $ONPREM_PIP_IP"

header "VPN Gateways"
# Use distinct ASNs if you later want BGP (example: 65010 & 65020); here we just set one and re-use or vary
create_vpn_gateway "$RG_NAME" "$HUB_VNET_NAME" "$HUB_PIP_NAME" "$HUB_VGW_NAME" 65010
create_vpn_gateway "$RG_NAME" "$ONPREM_VNET_NAME" "$ONPREM_PIP_NAME" "$ONPREM_VGW_NAME" 65020

wait_for_gateway "$RG_NAME" "$HUB_VGW_NAME"
wait_for_gateway "$RG_NAME" "$ONPREM_VGW_NAME"

# Refresh (should be unchanged due to static allocation)
HUB_PIP_IP=$(get_public_ip_address "$RG_NAME" "$HUB_PIP_NAME")
ONPREM_PIP_IP=$(get_public_ip_address "$RG_NAME" "$ONPREM_PIP_NAME")

header "Local Network Gateways"
create_local_network_gateway "$RG_NAME" "$LNG_ONPREM_NAME" "$ONPREM_PIP_IP" "$ONPREM_VNET_CIDR"
create_local_network_gateway "$RG_NAME" "$LNG_HUB_NAME" "$HUB_PIP_IP" "$HUB_VNET_CIDR"

header "Site-to-Site Connections"
create_connection "$RG_NAME" "$CONN_HUB_TO_ONPREM" "$HUB_VGW_NAME" "$LNG_ONPREM_NAME"
create_connection "$RG_NAME" "$CONN_ONPREM_TO_HUB" "$ONPREM_VGW_NAME" "$LNG_HUB_NAME"

header "Waiting for VPN Connections"
wait_for_connection "$RG_NAME" "$CONN_HUB_TO_ONPREM"
wait_for_connection "$RG_NAME" "$CONN_ONPREM_TO_HUB"

header "Summary"
cat <<EOF
Deployment complete in resource group: $RG_NAME (region: $REGION)

VNets:
  Hub:        $HUB_VNET_NAME ($HUB_VNET_CIDR)
  On-PremSim: $ONPREM_VNET_NAME ($ONPREM_VNET_CIDR)

Gateways:
  Hub:        $HUB_VGW_NAME (PIP: $HUB_PIP_IP)
  On-PremSim: $ONPREM_VGW_NAME (PIP: $ONPREM_PIP_IP)

Connections (status: Connected):
  $CONN_HUB_TO_ONPREM
  $CONN_ONPREM_TO_HUB

Validation examples:
  az network vpn-connection show -g $RG_NAME -n $CONN_HUB_TO_ONPREM --query '{status:connectionStatus,ingress:ingressBytesTransferred,egress:egressBytesTransferred}'
  az network vpn-connection show -g $RG_NAME -n $CONN_ONPREM_TO_HUB --query '{status:connectionStatus,ingress:ingressBytesTransferred,egress:egressBytesTransferred}'

Next steps:
  - Deploy test VMs into $HUB_SUBNET_NAME and $ONPREM_SUBNET_NAME to verify ping/SSH.
  - Add NSGs or Azure Firewall for traffic governance.
  - Rotate the shared key periodically (update both connections).
  - If you need BGP, gateways already have distinct ASNs (65010/65020); recreate connections with --enable-bgp true.
EOF