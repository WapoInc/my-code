#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="$SCRIPT_DIR/Multi-VM-CS-Ubuntu-VM.vm.bicep"

if [[ ! -f "$TEMPLATE_FILE" ]]; then
  echo "Bicep template not found: $TEMPLATE_FILE" >&2
  exit 1
fi

if ! command -v az >/dev/null 2>&1; then
  echo 'Azure CLI is required but was not found.' >&2
  exit 1
fi

if az account show --output none 2>/dev/null; then
  TENANT_ID="$(az account show --query tenantId --output tsv)"
  SUBSCRIPTION_ID="$(az account show --query id --output tsv)"

  if [[ -z "$TENANT_ID" || -z "$SUBSCRIPTION_ID" ]]; then
    echo 'Unable to determine the active Azure tenant or subscription.' >&2
    exit 1
  fi

  echo 'Refreshing the Azure CLI session. Complete the MFA device-code sign-in when prompted.'
  az logout
  az login \
    --tenant "$TENANT_ID" \
    --scope 'https://management.core.windows.net//.default' \
    --use-device-code \
    --output none
  az account set --subscription "$SUBSCRIPTION_ID"
else
  echo 'Sign in to Azure. Complete the MFA device-code sign-in when prompted.'
  az login \
    --scope 'https://management.core.windows.net//.default' \
    --use-device-code \
    --output none
fi

read_required() {
  local prompt="$1"
  local value=''

  while [[ -z "${value//[[:space:]]/}" ]]; do
    read -r -p "$prompt: " value
  done

  printf '%s' "$value"
}

read -r -p 'Location [southafricanorth]: ' LOCATION
LOCATION="${LOCATION:-southafricanorth}"

RESOURCE_GROUP_NAME="$(read_required 'Resource group name')"
VNET_NAME="$(read_required 'VNet name')"
SUBNET_NAME="$(read_required 'Subnet name')"
read -r -p 'VM name [SA-North-JB2]: ' VM_NAME
VM_NAME="${VM_NAME:-SA-North-JB2}"

while true; do
  read -r -p 'Number of Ubuntu VMs to deploy [1]: ' VM_COUNT
  VM_COUNT="${VM_COUNT:-1}"
  [[ "$VM_COUNT" =~ ^[0-9]+$ && "$VM_COUNT" -ge 1 ]] && break
  echo 'Enter a positive whole number.' >&2
done

# Linux VM (and host) names may be up to 64 characters.
if (( ${#VM_NAME} > 64 )); then
  echo 'VM name must be 64 characters or fewer.' >&2
  exit 1
fi

read -r -p 'Admin username [rootadmin]: ' ADMIN_USERNAME
ADMIN_USERNAME="${ADMIN_USERNAME:-rootadmin}"

while true; do
  read -r -s -p 'Admin password: ' ADMIN_PASSWORD
  echo
  [[ -n "$ADMIN_PASSWORD" ]] && break
  echo 'Admin password cannot be empty.' >&2
done

read -r -p 'VM size [Standard_B2s]: ' VM_SIZE
VM_SIZE="${VM_SIZE:-Standard_B2s}"

read -r -p 'Create a public IP address? [y/N]: ' CREATE_PUBLIC_IP_RESPONSE
if [[ "$CREATE_PUBLIC_IP_RESPONSE" =~ ^[Yy]([Ee][Ss])?$ ]]; then
  CREATE_PUBLIC_IP=true
else
  CREATE_PUBLIC_IP=false
fi

VNET_EXISTS=false
if [[ "$(az group exists --name "$RESOURCE_GROUP_NAME" --output tsv)" == 'true' ]] &&
  az network vnet show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$VNET_NAME" \
    --output none 2>/dev/null; then
  VNET_EXISTS=true
fi

if [[ "$VNET_EXISTS" == 'true' ]]; then
  CURRENT_VNET_CIDR="$(az network vnet show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$VNET_NAME" \
    --query 'addressSpace.addressPrefixes[0]' \
    --output tsv)"
  read -r -p "Keep current VNet CIDR $CURRENT_VNET_CIDR? [Y/n]: " KEEP_VNET_CIDR
  if [[ -z "$KEEP_VNET_CIDR" || "$KEEP_VNET_CIDR" =~ ^[Yy]([Ee][Ss])?$ ]]; then
    VNET_CIDR="$CURRENT_VNET_CIDR"
  else
    VNET_CIDR="$(read_required 'New VNet CIDR')"
  fi
else
  read -r -p 'VNet does not exist. VNet CIDR [10.20.0.0/16]: ' VNET_CIDR
  VNET_CIDR="${VNET_CIDR:-10.20.0.0/16}"
fi

SUBNET_EXISTS=false
if [[ "$VNET_EXISTS" == 'true' ]] &&
  az network vnet subnet show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --vnet-name "$VNET_NAME" \
    --name "$SUBNET_NAME" \
    --output none 2>/dev/null; then
  SUBNET_EXISTS=true
fi

if [[ "$SUBNET_EXISTS" == 'true' ]]; then
  CURRENT_SUBNET_CIDR="$(az network vnet subnet show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --vnet-name "$VNET_NAME" \
    --name "$SUBNET_NAME" \
    --query 'addressPrefix' \
    --output tsv)"

  if [[ -z "$CURRENT_SUBNET_CIDR" || "$CURRENT_SUBNET_CIDR" == 'null' || "$CURRENT_SUBNET_CIDR" == 'None' ]]; then
    CURRENT_SUBNET_CIDR="$(az network vnet subnet show \
      --resource-group "$RESOURCE_GROUP_NAME" \
      --vnet-name "$VNET_NAME" \
      --name "$SUBNET_NAME" \
      --query 'addressPrefixes[0]' \
      --output tsv)"
  fi

  if [[ -z "$CURRENT_SUBNET_CIDR" || "$CURRENT_SUBNET_CIDR" == 'null' || "$CURRENT_SUBNET_CIDR" == 'None' ]]; then
    echo "Unable to determine the current CIDR for subnet '$SUBNET_NAME'." >&2
    exit 1
  fi

  read -r -p "Keep current subnet CIDR $CURRENT_SUBNET_CIDR? [Y/n]: " KEEP_SUBNET_CIDR
  if [[ -z "$KEEP_SUBNET_CIDR" || "$KEEP_SUBNET_CIDR" =~ ^[Yy]([Ee][Ss])?$ ]]; then
    SUBNET_CIDR="$CURRENT_SUBNET_CIDR"
  else
    SUBNET_CIDR="$(read_required 'New subnet CIDR')"
  fi
else
  read -r -p "Subnet does not exist. Enter a CIDR within $VNET_CIDR [10.20.1.0/24]: " SUBNET_CIDR
  SUBNET_CIDR="${SUBNET_CIDR:-10.20.1.0/24}"
fi

# Build the list of VM names to deploy. A single VM keeps the base name; two or
# more append a "-<n>" suffix so each name is unique.
VM_NAMES=()
if (( VM_COUNT == 1 )); then
  VM_NAMES+=("$VM_NAME")
else
  for (( i = 1; i <= VM_COUNT; i++ )); do
    VM_NAMES+=("$VM_NAME-$i")
  done
fi

echo
echo 'Deployment settings:'
echo "  Location       : $LOCATION"
echo "  Resource group : $RESOURCE_GROUP_NAME"
echo "  VNet           : $VNET_NAME ($VNET_CIDR)"
echo "  Subnet         : $SUBNET_NAME ($SUBNET_CIDR)"
echo "  VMs            : ${VM_NAMES[*]} ($VM_SIZE)"
echo "  Private IP     : Dynamic"
echo "  Admin username : $ADMIN_USERNAME"
echo "  Public IP      : $CREATE_PUBLIC_IP"
echo '  NSG inbound    : TCP/22 from Any to Any'

read -r -p 'Deploy these resources? [y/N]: ' CONFIRMATION
if [[ ! "$CONFIRMATION" =~ ^[Yy]([Ee][Ss])?$ ]]; then
  echo 'Deployment cancelled.'
  exit 0
fi

# Provision the shared resource group, VNet and subnet once, up front. Doing
# this before the parallel VM deployments avoids concurrent writes to the same
# VNet (which Azure rejects with "AnotherOperationInProgress").
echo
echo 'Ensuring resource group, VNet and subnet exist...'
az group create --name "$RESOURCE_GROUP_NAME" --location "$LOCATION" --output none

if [[ "$VNET_EXISTS" != 'true' ]]; then
  az network vnet create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$VNET_NAME" \
    --address-prefixes "$VNET_CIDR" \
    --subnet-name "$SUBNET_NAME" \
    --subnet-prefixes "$SUBNET_CIDR" \
    --output none
elif [[ "$SUBNET_EXISTS" != 'true' ]]; then
  az network vnet subnet create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --vnet-name "$VNET_NAME" \
    --name "$SUBNET_NAME" \
    --address-prefixes "$SUBNET_CIDR" \
    --output none
fi

LOG_DIR="$(mktemp -d)"
PIDS=()
PID_NAMES=()

START_TIME=$(date +%s)
echo
echo "Start time: $(date '+%Y-%m-%d %H:%M:%S')"
echo "Starting ${#VM_NAMES[@]} VM deployment(s) in parallel..."

for CURRENT_VM_NAME in "${VM_NAMES[@]}"; do
  DEPLOYMENT_NAME="ubuntu-vm-$CURRENT_VM_NAME-$(date +%Y%m%d-%H%M%S)"
  LOG_FILE="$LOG_DIR/$CURRENT_VM_NAME.log"

  az deployment group create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$DEPLOYMENT_NAME" \
    --template-file "$TEMPLATE_FILE" \
    --parameters \
    "location=$LOCATION" \
    "vnetName=$VNET_NAME" \
    "subnetName=$SUBNET_NAME" \
    "vmName=$CURRENT_VM_NAME" \
    "adminUsername=$ADMIN_USERNAME" \
    "adminPassword=$ADMIN_PASSWORD" \
    "vmSize=$VM_SIZE" \
    "createPublicIp=$CREATE_PUBLIC_IP" \
    --query 'properties.outputs.{VMName:vmName.value,Username:adminUsername.value,PrivateIP:privateIpAddress.value,PublicIP:publicIpAddress.value}' \
    --output table >"$LOG_FILE" 2>&1 &

  PIDS+=("$!")
  PID_NAMES+=("$CURRENT_VM_NAME")
  echo "  Launched '$CURRENT_VM_NAME' (deployment: $DEPLOYMENT_NAME)"
done

FAILED=0
for idx in "${!PIDS[@]}"; do
  if wait "${PIDS[$idx]}"; then
    echo
    echo "Deployment for '${PID_NAMES[$idx]}' completed successfully:"
  else
    echo
    echo "Deployment for '${PID_NAMES[$idx]}' FAILED:" >&2
    FAILED=1
  fi
  cat "$LOG_DIR/${PID_NAMES[$idx]}.log"
done

rm -rf "$LOG_DIR"

END_TIME=$(date +%s)
ELAPSED=$(( END_TIME - START_TIME ))
ELAPSED_HMS=$(printf '%02d:%02d:%02d' $(( ELAPSED / 3600 )) $(( (ELAPSED % 3600) / 60 )) $(( ELAPSED % 60 )))

echo
echo "Start time : $(date -r "$START_TIME" '+%Y-%m-%d %H:%M:%S')"
echo "End time   : $(date -r "$END_TIME" '+%Y-%m-%d %H:%M:%S')"

echo
if (( FAILED )); then
  echo 'One or more VM deployments failed.' >&2
  exit 1
fi

echo "All ${#VM_NAMES[@]} VM deployment(s) completed successfully in- $ELAPSED_HMS (hh:mm:ss)"
