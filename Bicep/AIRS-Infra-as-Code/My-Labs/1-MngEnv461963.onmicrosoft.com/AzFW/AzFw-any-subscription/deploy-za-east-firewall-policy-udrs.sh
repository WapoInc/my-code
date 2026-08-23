#!/usr/bin/env bash

set -euo pipefail

# =============================================================================
# ZA-East hub-and-spoke firewall + network deployment (portable runner)
# =============================================================================
# Deploys into whatever subscription your Azure CLI is logged in to. It detects
# what already exists and only creates the missing pieces, so it is safe to
# re-run. It drives two Bicep modules through one subscription-scope template
# (ZA-East-Firewall-Policy-Udrs-rg.bicep):
#
#   1. ZA-East-Network-Prerequisites.bicep  (module: networkPrerequisites)
#   2. ZA-East-Firewall-Policy-Udrs.bicep   (module: firewallRouting)
#
# Components created / managed:
#   - Resource group                 container for every resource below.
#   - Hub VNet (10.20.0.0/16)         central network with five subnets:
#       * GatewaySubnet               hosts the VPN gateway.
#       * ZA-East-Hub                 workload subnet, protected by an NSG.
#       * AzureFirewallSubnet         required subnet for Azure Firewall data.
#       * AzureFirewallManagementSubnet  required for Basic firewall mgmt NIC.
#       * Ping-test                   scratch subnet for connectivity tests.
#   - Default NSG                     baseline security group on the hub subnet.
#   - Spoke VNets 1/2/3               10.21/22/23.0.0/24, each with Subnet-1.
#   - Hub<->spoke peerings            full mesh between hub and each spoke.
#   - Azure Firewall (Basic)          central egress/inspection point, plus a
#                                     data public IP and a management public IP.
#   - Firewall policy                 application + network rule collections.
#   - Log Analytics workspace         receives firewall diagnostic logs.
#   - Route tables (UDRs)             force subnet traffic through the firewall
#                                     private IP; applied in stages (see below).
#   - VPN gateway + public IP         route-based gateway in GatewaySubnet for
#                                     the site-to-site tunnel (brought up by the
#                                     separate deploy-za-east-s2s-fortigate.sh).
#
# Rollout stages (chosen interactively):
#   FirewallOnly | GatewayAndTestSpoke | AllSpokes | Full
#   control which UDR associations are applied so the topology can come up
#   incrementally.
#
# Self-healing behaviour:
#   - Removes a VPN gateway left in a Failed state before retrying.
#   - Replaces the VPN gateway public IP when it is Standard-without-zones and
#     unattached (Azure requires zones 1/2/3 on the Standard PIP).
#
# Prerequisites: az CLI, python3 (CIDR validation), and an authenticated Azure
# context (az login). Region/subscription/RG come from flags or AZURE_* vars.
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="$SCRIPT_DIR/ZA-East-Firewall-Policy-Udrs-rg.bicep"
LOCATION="${AZURE_LOCATION:-southafricanorth}"
TENANT_ID_OVERRIDE="${AZURE_TENANT_ID:-}"
SUBSCRIPTION_ID_OVERRIDE="${AZURE_SUBSCRIPTION_ID:-}"
RESOURCE_GROUP_OVERRIDE="${AZURE_RESOURCE_GROUP:-}"

usage() {
  cat <<'USAGE'
Usage: deploy-za-east-firewall-policy-udrs.sh [options]

Options:
  --tenant-id ID         Sign in to and deploy through this Microsoft Entra tenant.
  --subscription-id ID   Deploy to this Azure subscription.
  --resource-group NAME  Existing resource group containing the ZA-East networks.
  --location NAME        Azure region (default: southafricanorth).
  -h, --help             Show this help.

The same values can be supplied with AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID,
AZURE_RESOURCE_GROUP, and AZURE_LOCATION.
USAGE
}

while (( $# > 0 )); do
  case "$1" in
    --tenant-id)
      (( $# >= 2 )) || { echo "--tenant-id requires a value." >&2; exit 2; }
      TENANT_ID_OVERRIDE="$2"
      shift 2
      ;;
    --subscription-id)
      (( $# >= 2 )) || { echo "--subscription-id requires a value." >&2; exit 2; }
      SUBSCRIPTION_ID_OVERRIDE="$2"
      shift 2
      ;;
    --resource-group)
      (( $# >= 2 )) || { echo "--resource-group requires a value." >&2; exit 2; }
      RESOURCE_GROUP_OVERRIDE="$2"
      shift 2
      ;;
    --location)
      (( $# >= 2 )) || { echo "--location requires a value." >&2; exit 2; }
      LOCATION="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

# ---- Resource names (all derived from the region) ----
DEFAULT_RESOURCE_GROUP="za-east-${LOCATION}"
HUB_VNET_NAME="za-east-${LOCATION}-vnet"
HUB_WORKLOAD_NSG_NAME="za-east-${LOCATION}-default-nsg"
VPN_GATEWAY_NAME="za-east-${LOCATION}-vpngw"
VPN_GATEWAY_PUBLIC_IP_NAME="za-east-${LOCATION}-vpngw-pip"

# ---- Helper functions ----
# require_command: fail early if a needed CLI is missing.
# cidr_is_allowed: reject on-prem prefixes that overlap Azure or are not IPv4.
# prefixes_to_json / booleans_to_json: turn bash arrays into Bicep-ready JSON.
require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command '$1' is not installed or not in PATH." >&2
    exit 1
  fi
}

cidr_is_allowed() {
  local prefix="$1"
  python3 - "$prefix" <<'PY'
import ipaddress
import sys

try:
    candidate = ipaddress.ip_network(sys.argv[1], strict=False)
except ValueError:
    raise SystemExit(1)

azure_networks = [
    ipaddress.ip_network('10.20.0.0/16'),
    ipaddress.ip_network('10.21.0.0/24'),
    ipaddress.ip_network('10.22.0.0/24'),
    ipaddress.ip_network('10.23.0.0/24'),
]

if candidate.version != 4 or any(candidate.overlaps(network) for network in azure_networks):
    raise SystemExit(1)
PY
}

prefixes_to_json() {
  local json='['
  local separator=''
  local prefix

  for prefix in "$@"; do
    json+="${separator}\"${prefix}\""
    separator=','
  done

  printf '%s]' "$json"
}

booleans_to_json() {
  local json='['
  local separator=''
  local value

  for value in "$@"; do
    json+="${separator}${value}"
    separator=','
  done

  printf '%s]' "$json"
}

# ---- Verify tools and establish the Azure context ----
require_command az
require_command python3

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

if [[ -z "$SUBSCRIPTION_NAME" || -z "$SUBSCRIPTION_ID" || -z "$TENANT_ID" ]]; then
  echo "Azure CLI returned an incomplete default context. Run 'az login' and 'az account set --subscription <ID>' first." >&2
  exit 1
fi

if [[ -n "$TENANT_ID_OVERRIDE" && "$TENANT_ID" != "$TENANT_ID_OVERRIDE" ]]; then
  echo "Subscription '$SUBSCRIPTION_ID' belongs to tenant '$TENANT_ID', not '$TENANT_ID_OVERRIDE'." >&2
  exit 1
fi

if [[ -n "$RESOURCE_GROUP_OVERRIDE" ]]; then
  RESOURCE_GROUP_NAME="$RESOURCE_GROUP_OVERRIDE"
else
  read -r -p "Existing resource group [$DEFAULT_RESOURCE_GROUP]: " RESOURCE_GROUP_NAME
  RESOURCE_GROUP_NAME="${RESOURCE_GROUP_NAME:-$DEFAULT_RESOURCE_GROUP}"
fi

# ---- Register the resource providers this deployment needs ----
echo "Registering required Azure resource providers..."
for provider_namespace in Microsoft.Network Microsoft.OperationalInsights Microsoft.Insights; do
  az provider register \
    --namespace "$provider_namespace" \
    --subscription "$SUBSCRIPTION_ID" \
    --wait \
    --output none
done

# ---- Discover which resources already exist so we only create the gaps ----
if az group show --name "$RESOURCE_GROUP_NAME" --subscription "$SUBSCRIPTION_ID" >/dev/null 2>&1; then
  CREATE_RESOURCE_GROUP=false
else
  CREATE_RESOURCE_GROUP=true
fi

spoke_vnet_names=(
  "za-east-spoke-1-vnet"
  "za-east-spoke-2-vnet"
  "za-east-spoke-3-vnet"
)

if az network vnet show --resource-group "$RESOURCE_GROUP_NAME" --name "$HUB_VNET_NAME" --subscription "$SUBSCRIPTION_ID" >/dev/null 2>&1; then
  CREATE_HUB_VNET=false
  HUB_VNET_LOCATION="$(az network vnet show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$HUB_VNET_NAME" \
    --subscription "$SUBSCRIPTION_ID" \
    --query location \
    --output tsv)"
  if [[ "$LOCATION" != "$HUB_VNET_LOCATION" ]]; then
    echo "Using hub VNet location '$HUB_VNET_LOCATION' instead of requested location '$LOCATION'."
    LOCATION="$HUB_VNET_LOCATION"
  fi
else
  CREATE_HUB_VNET=true
fi

if az network nsg show --resource-group "$RESOURCE_GROUP_NAME" --name "$HUB_WORKLOAD_NSG_NAME" --subscription "$SUBSCRIPTION_ID" >/dev/null 2>&1; then
  CREATE_HUB_WORKLOAD_NSG=false
else
  CREATE_HUB_WORKLOAD_NSG=true
fi

subnet_missing() {
  local vnet_name="$1"
  local subnet_name="$2"
  if az network vnet subnet show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --vnet-name "$vnet_name" \
    --name "$subnet_name" \
    --subscription "$SUBSCRIPTION_ID" >/dev/null 2>&1; then
    printf false
  else
    printf true
  fi
}

if [[ "$CREATE_HUB_VNET" == true ]]; then
  CREATE_GATEWAY_SUBNET=true
  CREATE_FIREWALL_SUBNET=true
  CREATE_FIREWALL_MANAGEMENT_SUBNET=true
  CREATE_HUB_WORKLOAD_SUBNET=true
  CREATE_PING_TEST_SUBNET=true
else
  CREATE_GATEWAY_SUBNET="$(subnet_missing "$HUB_VNET_NAME" GatewaySubnet)"
  CREATE_FIREWALL_SUBNET="$(subnet_missing "$HUB_VNET_NAME" AzureFirewallSubnet)"
  CREATE_FIREWALL_MANAGEMENT_SUBNET="$(subnet_missing "$HUB_VNET_NAME" AzureFirewallManagementSubnet)"
  CREATE_HUB_WORKLOAD_SUBNET="$(subnet_missing "$HUB_VNET_NAME" ZA-East-Hub)"
  CREATE_PING_TEST_SUBNET="$(subnet_missing "$HUB_VNET_NAME" Ping-test)"
fi

# ---- VPN gateway: reuse if healthy, delete if failed, otherwise create ----
EXISTING_VPN_GATEWAY_NAME="$(az network vnet-gateway list \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --subscription "$SUBSCRIPTION_ID" \
  --query "[?contains(ipConfigurations[0].subnet.id, '/virtualNetworks/${HUB_VNET_NAME}/subnets/GatewaySubnet')].name | [0]" \
  --output tsv 2>/dev/null || true)"

if [[ -n "$EXISTING_VPN_GATEWAY_NAME" ]]; then
  EXISTING_VPN_GATEWAY_STATE="$(az network vnet-gateway show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$EXISTING_VPN_GATEWAY_NAME" \
    --subscription "$SUBSCRIPTION_ID" \
    --query provisioningState \
    --output tsv)"

  if [[ "$EXISTING_VPN_GATEWAY_STATE" == "Succeeded" ]]; then
    VPN_GATEWAY_NAME="$EXISTING_VPN_GATEWAY_NAME"
    CREATE_VPN_GATEWAY=false
    CREATE_VPN_GATEWAY_PUBLIC_IP=false
  elif [[ "$EXISTING_VPN_GATEWAY_STATE" == "Failed" ]]; then
    echo "Removing failed VPN gateway '$EXISTING_VPN_GATEWAY_NAME' before retrying deployment..."
    az network vnet-gateway delete \
      --resource-group "$RESOURCE_GROUP_NAME" \
      --name "$EXISTING_VPN_GATEWAY_NAME" \
      --subscription "$SUBSCRIPTION_ID" \
      --output none
    CREATE_VPN_GATEWAY=true
  else
    echo "VPN gateway '$EXISTING_VPN_GATEWAY_NAME' is in state '$EXISTING_VPN_GATEWAY_STATE'. Wait for it to finish before rerunning this deployment." >&2
    exit 1
  fi
else
  CREATE_VPN_GATEWAY=true
fi

# ---- VPN gateway public IP: keep only if Standard with zones 1/2/3 ----
if [[ "$CREATE_VPN_GATEWAY" == true ]]; then
  if az network public-ip show --resource-group "$RESOURCE_GROUP_NAME" --name "$VPN_GATEWAY_PUBLIC_IP_NAME" --subscription "$SUBSCRIPTION_ID" >/dev/null 2>&1; then
    VPN_PIP_SKU="$(az network public-ip show \
      --resource-group "$RESOURCE_GROUP_NAME" \
      --name "$VPN_GATEWAY_PUBLIC_IP_NAME" \
      --subscription "$SUBSCRIPTION_ID" \
      --query sku.name \
      --output tsv)"
    VPN_PIP_ZONES="$(az network public-ip show \
      --resource-group "$RESOURCE_GROUP_NAME" \
      --name "$VPN_GATEWAY_PUBLIC_IP_NAME" \
      --subscription "$SUBSCRIPTION_ID" \
      --query "join(',', not_null(zones, \`[]\`))" \
      --output tsv)"
    VPN_PIP_IP_CONFIGURATION_ID="$(az network public-ip show \
      --resource-group "$RESOURCE_GROUP_NAME" \
      --name "$VPN_GATEWAY_PUBLIC_IP_NAME" \
      --subscription "$SUBSCRIPTION_ID" \
      --query ipConfiguration.id \
      --output tsv)"

    if [[ "$VPN_PIP_SKU" == "Standard" && "$VPN_PIP_ZONES" == "1,2,3" ]]; then
      CREATE_VPN_GATEWAY_PUBLIC_IP=false
    elif [[ -n "$VPN_PIP_IP_CONFIGURATION_ID" ]]; then
      echo "VPN gateway public IP '$VPN_GATEWAY_PUBLIC_IP_NAME' is incompatible (SKU '$VPN_PIP_SKU', zones '${VPN_PIP_ZONES:-none}') and attached to '$VPN_PIP_IP_CONFIGURATION_ID'." >&2
      echo "Detach it before rerunning this deployment." >&2
      exit 1
    else
      echo "Replacing incompatible VPN gateway public IP '$VPN_GATEWAY_PUBLIC_IP_NAME' (SKU '$VPN_PIP_SKU', zones '${VPN_PIP_ZONES:-none}')..."
      az network public-ip delete \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --name "$VPN_GATEWAY_PUBLIC_IP_NAME" \
        --subscription "$SUBSCRIPTION_ID"
      CREATE_VPN_GATEWAY_PUBLIC_IP=true
    fi
  else
    CREATE_VPN_GATEWAY_PUBLIC_IP=true
  fi
fi

CREATE_SPOKE_VNETS=()
CREATE_SPOKE_SUBNETS=()
CREATE_HUB_TO_SPOKE_PEERINGS=()
CREATE_SPOKE_TO_HUB_PEERINGS=()

for index in 0 1 2; do
  spoke_vnet_name="${spoke_vnet_names[$index]}"
  spoke_name="${spoke_vnet_name%-vnet}"

  if az network vnet show --resource-group "$RESOURCE_GROUP_NAME" --name "$spoke_vnet_name" --subscription "$SUBSCRIPTION_ID" >/dev/null 2>&1; then
    CREATE_SPOKE_VNETS+=(false)
    CREATE_SPOKE_SUBNETS+=("$(subnet_missing "$spoke_vnet_name" Subnet-1)")
  else
    CREATE_SPOKE_VNETS+=(true)
    CREATE_SPOKE_SUBNETS+=(true)
  fi

  if az network vnet peering show --resource-group "$RESOURCE_GROUP_NAME" --vnet-name "$HUB_VNET_NAME" --name "hub-to-$spoke_name" --subscription "$SUBSCRIPTION_ID" >/dev/null 2>&1; then
    CREATE_HUB_TO_SPOKE_PEERINGS+=(false)
  else
    CREATE_HUB_TO_SPOKE_PEERINGS+=(true)
  fi

  if az network vnet peering show --resource-group "$RESOURCE_GROUP_NAME" --vnet-name "$spoke_vnet_name" --name "$spoke_name-to-hub" --subscription "$SUBSCRIPTION_ID" >/dev/null 2>&1; then
    CREATE_SPOKE_TO_HUB_PEERINGS+=(false)
  else
    CREATE_SPOKE_TO_HUB_PEERINGS+=(true)
  fi
done

CREATE_SPOKE_VNETS_JSON="$(booleans_to_json "${CREATE_SPOKE_VNETS[@]}")"
CREATE_SPOKE_SUBNETS_JSON="$(booleans_to_json "${CREATE_SPOKE_SUBNETS[@]}")"
CREATE_HUB_TO_SPOKE_PEERINGS_JSON="$(booleans_to_json "${CREATE_HUB_TO_SPOKE_PEERINGS[@]}")"
CREATE_SPOKE_TO_HUB_PEERINGS_JSON="$(booleans_to_json "${CREATE_SPOKE_TO_HUB_PEERINGS[@]}")"
required_networks=("$HUB_VNET_NAME" "${spoke_vnet_names[@]}")

learned_prefixes=()

if [[ "$CREATE_VPN_GATEWAY" == false ]]; then
  while IFS= read -r prefix; do
    if cidr_is_allowed "$prefix"; then
      learned_prefixes+=("$prefix")
    fi
  done < <(az network vnet-gateway list-learned-routes \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$VPN_GATEWAY_NAME" \
    --subscription "$SUBSCRIPTION_ID" \
    --query 'value[].network' \
    --output tsv 2>/dev/null || true)
fi

echo
echo "Candidate on-premises prefixes learned from the VPN gateway:"
if (( ${#learned_prefixes[@]} == 0 )); then
  echo "  None discovered. Enter approved prefixes manually if required."
  learned_default=""
else
  printf '  %s\n' "${learned_prefixes[@]}"
  learned_default="${learned_prefixes[*]}"
fi

echo "Azure prefixes and 0.0.0.0/0 are rejected from this list."
read -r -p "Approved on-premises CIDRs, separated by spaces [$learned_default]: " PREFIX_INPUT
PREFIX_INPUT="${PREFIX_INPUT:-$learned_default}"
read -r -a APPROVED_PREFIXES <<< "$PREFIX_INPUT"

for prefix in "${APPROVED_PREFIXES[@]}"; do
  if ! cidr_is_allowed "$prefix"; then
    echo "Rejected prefix '$prefix'. Enter IPv4 CIDRs that do not overlap the hub or spoke networks; 0.0.0.0/0 is not permitted." >&2
    exit 1
  fi
done

APPROVED_PREFIXES_JSON="$(prefixes_to_json "${APPROVED_PREFIXES[@]}")"

stage_options=(
  "FirewallOnly"
  "GatewayAndTestSpoke"
  "AllSpokes"
  "Full"
)

echo
echo "Select the rollout stage:"
PS3="Enter selection (1-${#stage_options[@]}): "
select DEPLOYMENT_STAGE in "${stage_options[@]}"; do
  [[ -n "$DEPLOYMENT_STAGE" ]] && break
  echo "Invalid selection."
done

read -r -p "Route Internet traffic through the firewall? [Y/n] " INTERNET_EGRESS_REPLY
if [[ "$INTERNET_EGRESS_REPLY" =~ ^[Nn]$ ]]; then
  ENABLE_INTERNET_EGRESS=false
else
  ENABLE_INTERNET_EGRESS=true
fi

LOG_ANALYTICS_WORKSPACE_NAME="AzFW-Basic-LA"

EXISTING_FIREWALL_ZONES="$(az network firewall show \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --name "AzFW-ZA-East-vDC" \
  --subscription "$SUBSCRIPTION_ID" \
  --query 'zones' \
  --output json 2>/dev/null || true)"

if [[ -n "$EXISTING_FIREWALL_ZONES" && "$EXISTING_FIREWALL_ZONES" != "null" ]]; then
  FIREWALL_ZONES_JSON="$EXISTING_FIREWALL_ZONES"
  echo "Preserving the existing firewall availability zones: $FIREWALL_ZONES_JSON"
else
  read -r -p "Use zone-redundant firewall and public IP deployment? [Y/n] " ZONE_REPLY
  if [[ "$ZONE_REPLY" =~ ^[Nn]$ ]]; then
    FIREWALL_ZONES_JSON='[]'
  else
    FIREWALL_ZONES_JSON='["1","2","3"]'
  fi
fi

if [[ "$DEPLOYMENT_STAGE" != "FirewallOnly" ]]; then
  SNAPSHOT_FILE="$SCRIPT_DIR/za-east-route-table-associations-$(date -u +%Y%m%d-%H%M%S).tsv"
  {
    printf 'vnet\tsubnet\tcurrentRouteTableId\n'
    for vnet_name in "${required_networks[@]}"; do
      az network vnet subnet list \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --vnet-name "$vnet_name" \
        --subscription "$SUBSCRIPTION_ID" \
        --query "[].['$vnet_name',name,routeTable.id]" \
        --output tsv 2>/dev/null || true
    done
  } > "$SNAPSHOT_FILE"
  echo "Saved current route-table associations to $SNAPSHOT_FILE"
fi

echo
echo "Deployment summary:"
echo "  Subscription:           $SUBSCRIPTION_NAME ($SUBSCRIPTION_ID)"
echo "  Tenant:                 $TENANT_ID"
echo "  Resource group:         $RESOURCE_GROUP_NAME"
echo "  Location:               $LOCATION"
echo "  Stage:                  $DEPLOYMENT_STAGE"
echo "  On-premises prefixes:   ${PREFIX_INPUT:-None}"
echo "  Internet egress UDR:    $ENABLE_INTERNET_EGRESS"
echo "  Internet policy rule:   HTTP/80 and HTTPS/443 to all FQDNs"
echo "  Diagnostics workspace:  $LOG_ANALYTICS_WORKSPACE_NAME (created or updated)"
echo "  Firewall zones:         $FIREWALL_ZONES_JSON"
echo "  Create resource group:  $CREATE_RESOURCE_GROUP"
echo "  Create hub VNet:        $CREATE_HUB_VNET"
echo "  Create hub NSG:         $CREATE_HUB_WORKLOAD_NSG"
echo "  Create hub subnets:     gateway=$CREATE_GATEWAY_SUBNET firewall=$CREATE_FIREWALL_SUBNET management=$CREATE_FIREWALL_MANAGEMENT_SUBNET workload=$CREATE_HUB_WORKLOAD_SUBNET ping=$CREATE_PING_TEST_SUBNET"
echo "  Create VPN gateway IP:  $CREATE_VPN_GATEWAY_PUBLIC_IP ($VPN_GATEWAY_PUBLIC_IP_NAME)"
echo "  Create VPN gateway:     $CREATE_VPN_GATEWAY ($VPN_GATEWAY_NAME, Basic non-AZ)"
echo "  Create spoke VNets:     $CREATE_SPOKE_VNETS_JSON"
echo "  Create spoke subnets:   $CREATE_SPOKE_SUBNETS_JSON"
echo "  Create hub peerings:    $CREATE_HUB_TO_SPOKE_PEERINGS_JSON"
echo "  Create spoke peerings:  $CREATE_SPOKE_TO_HUB_PEERINGS_JSON"
echo

POLICY_COUNT="$(az policy assignment list \
  --scope "/subscriptions/$SUBSCRIPTION_ID" \
  --query 'length(@)' \
  --output tsv)"
echo "Subscription-scope policy assignments detected: $POLICY_COUNT"

# ---- Compile, validate, then deploy the subscription-scope template ----
echo "Building Bicep templates..."
az bicep build --file "$TEMPLATE_FILE" --stdout >/dev/null

DEPLOYMENT_NAME="za-east-firewall-$(date -u +%Y%m%d-%H%M%S)"
COMMON_PARAMETERS=(
  "resourceGroupName=$RESOURCE_GROUP_NAME"
  "location=$LOCATION"
  "hubVnetName=$HUB_VNET_NAME"
  "hubWorkloadNsgName=$HUB_WORKLOAD_NSG_NAME"
  "vpnGatewayName=$VPN_GATEWAY_NAME"
  "vpnGatewayPublicIpName=$VPN_GATEWAY_PUBLIC_IP_NAME"
  "deploymentStage=$DEPLOYMENT_STAGE"
  "approvedOnPremisesPrefixes=$APPROVED_PREFIXES_JSON"
  "enableInternetEgressRouting=$ENABLE_INTERNET_EGRESS"
  "logAnalyticsWorkspaceName=$LOG_ANALYTICS_WORKSPACE_NAME"
  "firewallZones=$FIREWALL_ZONES_JSON"
  "createHubVnet=$CREATE_HUB_VNET"
  "createHubWorkloadNsg=$CREATE_HUB_WORKLOAD_NSG"
  "createGatewaySubnet=$CREATE_GATEWAY_SUBNET"
  "createVpnGatewayPublicIp=$CREATE_VPN_GATEWAY_PUBLIC_IP"
  "createVpnGateway=$CREATE_VPN_GATEWAY"
  "createFirewallSubnet=$CREATE_FIREWALL_SUBNET"
  "createFirewallManagementSubnet=$CREATE_FIREWALL_MANAGEMENT_SUBNET"
  "createHubWorkloadSubnet=$CREATE_HUB_WORKLOAD_SUBNET"
  "createPingTestSubnet=$CREATE_PING_TEST_SUBNET"
  "createSpokeVnets=$CREATE_SPOKE_VNETS_JSON"
  "createSpokeSubnets=$CREATE_SPOKE_SUBNETS_JSON"
  "createHubToSpokePeerings=$CREATE_HUB_TO_SPOKE_PEERINGS_JSON"
  "createSpokeToHubPeerings=$CREATE_SPOKE_TO_HUB_PEERINGS_JSON"
)

echo "Running subscription deployment validation..."
az deployment sub validate \
  --name "$DEPLOYMENT_NAME" \
  --location "$LOCATION" \
  --template-file "$TEMPLATE_FILE" \
  --parameters "${COMMON_PARAMETERS[@]}" \
  --subscription "$SUBSCRIPTION_ID" \
  --output table

echo
echo "Validation succeeded. Starting deployment..."

az deployment sub create \
  --name "$DEPLOYMENT_NAME" \
  --location "$LOCATION" \
  --template-file "$TEMPLATE_FILE" \
  --parameters "${COMMON_PARAMETERS[@]}" \
  --subscription "$SUBSCRIPTION_ID" \
  --query 'properties.outputs' \
  --output json
