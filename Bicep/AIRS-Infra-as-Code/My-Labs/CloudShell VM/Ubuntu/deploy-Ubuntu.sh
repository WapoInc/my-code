#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="$SCRIPT_DIR/CS-Ubuntu-VM.bicep"

if [[ ! -f "$TEMPLATE_FILE" ]]; then
  echo "Bicep template not found: $TEMPLATE_FILE" >&2
  exit 1
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
VM_NAME="$(read_required 'VM name')"

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
  read -r -p 'VNet does not exist. VNet CIDR [10.0.0.0/16]: ' VNET_CIDR
  VNET_CIDR="${VNET_CIDR:-10.0.0.0/16}"
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
  read -r -p "Subnet does not exist. Enter a CIDR within $VNET_CIDR [10.0.1.0/24]: " SUBNET_CIDR
  SUBNET_CIDR="${SUBNET_CIDR:-10.0.1.0/24}"
fi

DEPLOYMENT_NAME="ubuntu-vm-$(date +%Y%m%d-%H%M%S)"

echo
echo 'Deployment settings:'
echo "  Deployment     : $DEPLOYMENT_NAME"
echo "  Location       : $LOCATION"
echo "  Resource group : $RESOURCE_GROUP_NAME"
echo "  VNet           : $VNET_NAME ($VNET_CIDR)"
echo "  Subnet         : $SUBNET_NAME ($SUBNET_CIDR)"
echo "  VM             : $VM_NAME ($VM_SIZE)"
echo "  Admin username : $ADMIN_USERNAME"
echo "  Public IP      : $CREATE_PUBLIC_IP"
echo '  NSG inbound    : TCP/22 from Any to Any'

read -r -p 'Deploy these resources? [y/N]: ' CONFIRMATION
if [[ ! "$CONFIRMATION" =~ ^[Yy]([Ee][Ss])?$ ]]; then
  echo 'Deployment cancelled.'
  exit 0
fi

DEPLOYMENT_ARGUMENTS=(
  deployment sub create
  --name "$DEPLOYMENT_NAME"
  --location "$LOCATION"
  --template-file "$TEMPLATE_FILE"
  --parameters
  "resourceGroupName=$RESOURCE_GROUP_NAME"
  "location=$LOCATION"
  "vnetName=$VNET_NAME"
  "subnetName=$SUBNET_NAME"
  "vmName=$VM_NAME"
  "adminUsername=$ADMIN_USERNAME"
  "adminPassword=$ADMIN_PASSWORD"
  "vmSize=$VM_SIZE"
  "vnetCidr=$VNET_CIDR"
  "subnetCidr=$SUBNET_CIDR"
  "createPublicIp=$CREATE_PUBLIC_IP"
  --query 'properties.outputs.{VMName:vmName.value,Username:adminUsername.value,PrivateIP:privateIpAddress.value,PublicIP:publicIpAddress.value}'
  --output table
)

az "${DEPLOYMENT_ARGUMENTS[@]}"

echo
echo "Deployment '$DEPLOYMENT_NAME' completed successfully."