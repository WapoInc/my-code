#!/usr/bin/env bash
set -euo pipefail

##############################################################################
# Create an Ubuntu 22.04 VM in the CURRENT Cloud Shell tenant/subscription
##############################################################################

# --- Show where we are (no login needed in Cloud Shell) ----------------------
echo "Signed in as : $(az account show --query user.name -o tsv)"
echo "Tenant       : $(az account show --query tenantId -o tsv)"
echo "Subscription : $(az account show --query name -o tsv)  ($(az account show --query id -o tsv))"
echo

read -p "Continue in THIS subscription? (y/n): " ok
[[ "$ok" == "y" || "$ok" == "Y" ]] || { echo "Aborted. Run 'az account set --subscription <name-or-id>' first."; exit 1; }
echo

# --- Prompts ----------------------------------------------------------------
read -p "Azure region (e.g. eastus, westeurope):           " LOCATION
read -p "Resource group name:                              " RG
read -p "VNet name:                                        " VNET
read -p "Subnet name:                                      " SUBNET
read -p "VM name:                                          " VMNAME
read -p "Admin username:                                   " ADMIN_USER

while true; do
  read -s -p "Admin password (12-72 chars, 3 of: upper/lower/digit/symbol): " ADMIN_PASS; echo
  read -s -p "Confirm password:                                             " ADMIN_PASS2; echo
  [[ "$ADMIN_PASS" == "$ADMIN_PASS2" ]] && break
  echo "Passwords do not match, try again."
done
echo

# --- Optional overrides (press Enter for defaults) --------------------------
read -p "VM size [Standard_B2s]:                            " VMSIZE
VMSIZE="${VMSIZE:-Standard_B2s}"
read -p "VNet address space (only used if VNet is new) [10.0.0.0/16]: " VNET_CIDR
VNET_CIDR="${VNET_CIDR:-10.0.0.0/16}"
read -p "Subnet prefix (only used if subnet is new) [10.0.1.0/24]:     " SUBNET_CIDR
SUBNET_CIDR="${SUBNET_CIDR:-10.0.1.0/24}"

UBUNTU_IMAGE="Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest"

# --- Resource group -------------------------------------------------------
if [[ "$(az group exists --name "$RG")" == "false" ]]; then
  echo "Creating resource group '$RG' in '$LOCATION'..."
  az group create --name "$RG" --location "$LOCATION" --output none
else
  echo "Resource group '$RG' already exists."
fi

# --- VNet + subnet (create if missing) ----------------------------------
if ! az network vnet show -g "$RG" -n "$VNET" &>/dev/null; then
  echo "Creating VNet '$VNET' ($VNET_CIDR) with subnet '$SUBNET' ($SUBNET_CIDR)..."
  az network vnet create \
    --resource-group "$RG" \
    --name "$VNET" \
    --location "$LOCATION" \
    --address-prefixes "$VNET_CIDR" \
    --subnet-name "$SUBNET" \
    --subnet-prefixes "$SUBNET_CIDR" \
    --output none
else
  echo "VNet '$VNET' exists."
  if ! az network vnet subnet show -g "$RG" --vnet-name "$VNET" -n "$SUBNET" &>/dev/null; then
    echo "Creating subnet '$SUBNET' ($SUBNET_CIDR) in existing VNet..."
    az network vnet subnet create \
      --resource-group "$RG" \
      --vnet-name "$VNET" \
      --name "$SUBNET" \
      --address-prefixes "$SUBNET_CIDR" \
      --output none
  else
    echo "Subnet '$SUBNET' exists."
  fi
fi

# --- Create the VM ------------------------------------------------------
echo
echo "Creating VM '$VMNAME' ($VMSIZE, Ubuntu 22.04)..."
az vm create \
  --resource-group "$RG" \
  --name "$VMNAME" \
  --location "$LOCATION" \
  --image "$UBUNTU_IMAGE" \
  --size "$VMSIZE" \
  --vnet-name "$VNET" \
  --subnet "$SUBNET" \
  --authentication-type password \
  --admin-username "$ADMIN_USER" \
  --admin-password "$ADMIN_PASS" \
  --public-ip-sku Standard \
  --output json \
  --query "{PublicIP:publicIpAddress, PrivateIP:privateIpAddress, PowerState:powerState}"

echo
echo "Done. SSH with:  ssh ${ADMIN_USER}@<PublicIP>"
echo "If SSH is blocked, open port 22:"
echo "  az vm open-port --resource-group \"$RG\" --name \"$VMNAME\" --port 22"
