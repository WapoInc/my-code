#!/bin/bash

# =============================================================================
# vWAN-2Hubs-SAN-NE-2Spokes-2VMs.sh
# =============================================================================
# Creates:
#   - Virtual WAN
#   - Hub 1 : South Africa North  (192.168.111.0/24)
#   - Hub 2 : Northern Europe     (192.168.112.0/24)
#   - Spoke VNet per hub (connected to its hub)
#   - 1 Ubuntu 22.04 VM per spoke  (public IP enabled)
#   - NSG with SSH inbound rule (restricted to your public IP)
#
# Usage: chmod +x vWAN-2Hubs-SAN-NE-2Spokes-2VMs.sh && ./vWAN-2Hubs-SAN-NE-2Spokes-2VMs.sh
# =============================================================================

# =============================================================================
# VARIABLES
# =============================================================================

RG="vwan-san-ne-rg"
VWAN="vwan-san-ne"

# Hub 1 – South Africa North
HUB1_NAME="hub-southafricanorth"
HUB1_LOCATION="southafricanorth"
HUB1_CIDR="192.168.111.0/24"

# Hub 2 – Northern Europe
HUB2_NAME="hub-northerneurope"
HUB2_LOCATION="northeurope"
HUB2_CIDR="192.168.112.0/24"

# Spoke 1 (attached to Hub 1 – South Africa North)
SPOKE1_VNET="spoke1-san-vnet"
SPOKE1_CIDR="10.111.0.0/24"
SPOKE1_SUBNET="spoke1-subnet"
SPOKE1_SUBNET_CIDR="10.111.0.0/25"
SPOKE1_CONN="spoke1-to-hub1"

# Spoke 2 (attached to Hub 2 – Northern Europe)
SPOKE2_VNET="spoke2-ne-vnet"
SPOKE2_CIDR="10.112.0.0/24"
SPOKE2_SUBNET="spoke2-subnet"
SPOKE2_SUBNET_CIDR="10.112.0.0/25"
SPOKE2_CONN="spoke2-to-hub2"

# VM Configuration
VM_SIZE="Standard_B2s"
ADMIN_USERNAME="rootadmin"
ADMIN_PASSWORD="P@ssw0rd123!"
IMAGE="Ubuntu2204"
VM1_NAME="vm-spoke1-san"
VM2_NAME="vm-spoke2-ne"

# NSG names
NSG1="nsg-spoke1-san"
NSG2="nsg-spoke2-ne"

# Caller's public IP (used to restrict SSH access)
MY_IP=$(curl -4 -s ifconfig.io)
echo "Detected public IP for SSH access: $MY_IP"

# =============================================================================
# HELPER – exit on error
# =============================================================================
check() {
    if [ $? -ne 0 ]; then
        echo "ERROR: $1 failed. Exiting."
        exit 1
    fi
}

# =============================================================================
# STEP 1 – Resource Group
# =============================================================================
echo ""
echo "=== Step 1: Creating resource group: $RG in $HUB1_LOCATION ==="
az group create \
    --name "$RG" \
    --location "$HUB1_LOCATION" \
    --output none
check "Resource group create"

# =============================================================================
# STEP 2 – Virtual WAN
# =============================================================================
echo ""
echo "=== Step 2: Creating Virtual WAN: $VWAN ==="
az network vwan create \
    --resource-group "$RG" \
    --name "$VWAN" \
    --location "$HUB1_LOCATION" \
    --type Standard \
    --output none
check "Virtual WAN create"

# =============================================================================
# STEP 3 – Virtual Hubs (both created in parallel with --no-wait)
# =============================================================================
echo ""
echo "=== Step 3: Creating Hub 1 ($HUB1_NAME) and Hub 2 ($HUB2_NAME) in parallel ==="

az network vhub create \
    --resource-group "$RG" \
    --name "$HUB1_NAME" \
    --vwan "$VWAN" \
    --location "$HUB1_LOCATION" \
    --address-prefix "$HUB1_CIDR" \
    --sku Standard \
    --no-wait \
    --output none

az network vhub create \
    --resource-group "$RG" \
    --name "$HUB2_NAME" \
    --vwan "$VWAN" \
    --location "$HUB2_LOCATION" \
    --address-prefix "$HUB2_CIDR" \
    --sku Standard \
    --no-wait \
    --output none

echo "Waiting for Hub 1 to reach Succeeded state..."
az network vhub wait \
    --resource-group "$RG" \
    --name "$HUB1_NAME" \
    --created \
    --interval 30 \
    --timeout 1800
check "Hub 1 provisioning"

echo "Waiting for Hub 2 to reach Succeeded state..."
az network vhub wait \
    --resource-group "$RG" \
    --name "$HUB2_NAME" \
    --created \
    --interval 30 \
    --timeout 1800
check "Hub 2 provisioning"

echo "Both hubs are ready."

# =============================================================================
# STEP 4 – Spoke VNets + Subnets
# =============================================================================
echo ""
echo "=== Step 4: Creating Spoke VNets ==="

az network vnet create \
    --resource-group "$RG" \
    --name "$SPOKE1_VNET" \
    --location "$HUB1_LOCATION" \
    --address-prefixes "$SPOKE1_CIDR" \
    --subnet-name "$SPOKE1_SUBNET" \
    --subnet-prefixes "$SPOKE1_SUBNET_CIDR" \
    --output none
check "Spoke 1 VNet create"

az network vnet create \
    --resource-group "$RG" \
    --name "$SPOKE2_VNET" \
    --location "$HUB2_LOCATION" \
    --address-prefixes "$SPOKE2_CIDR" \
    --subnet-name "$SPOKE2_SUBNET" \
    --subnet-prefixes "$SPOKE2_SUBNET_CIDR" \
    --output none
check "Spoke 2 VNet create"

# =============================================================================
# STEP 5 – NSGs (SSH restricted to caller's public IP)
# =============================================================================
echo ""
echo "=== Step 5: Creating NSGs ==="

az network nsg create \
    --resource-group "$RG" \
    --name "$NSG1" \
    --location "$HUB1_LOCATION" \
    --output none
check "NSG 1 create"

az network nsg rule create \
    --resource-group "$RG" \
    --nsg-name "$NSG1" \
    --name "Allow-SSH-Inbound" \
    --priority 100 \
    --direction Inbound \
    --source-address-prefixes "$MY_IP" \
    --source-port-ranges '*' \
    --destination-address-prefixes '*' \
    --destination-port-ranges 22 \
    --protocol Tcp \
    --access Allow \
    --description "Allow SSH from admin IP" \
    --output none
check "NSG 1 SSH rule"

az network nsg create \
    --resource-group "$RG" \
    --name "$NSG2" \
    --location "$HUB2_LOCATION" \
    --output none
check "NSG 2 create"

az network nsg rule create \
    --resource-group "$RG" \
    --nsg-name "$NSG2" \
    --name "Allow-SSH-Inbound" \
    --priority 100 \
    --direction Inbound \
    --source-address-prefixes "$MY_IP" \
    --source-port-ranges '*' \
    --destination-address-prefixes '*' \
    --destination-port-ranges 22 \
    --protocol Tcp \
    --access Allow \
    --description "Allow SSH from admin IP" \
    --output none
check "NSG 2 SSH rule"

# Associate NSGs with spoke subnets
az network vnet subnet update \
    --resource-group "$RG" \
    --vnet-name "$SPOKE1_VNET" \
    --name "$SPOKE1_SUBNET" \
    --network-security-group "$NSG1" \
    --output none
check "NSG 1 subnet association"

az network vnet subnet update \
    --resource-group "$RG" \
    --vnet-name "$SPOKE2_VNET" \
    --name "$SPOKE2_SUBNET" \
    --network-security-group "$NSG2" \
    --output none
check "NSG 2 subnet association"

# =============================================================================
# STEP 6 – Ubuntu VMs (created in parallel with --no-wait)
# =============================================================================
echo ""
echo "=== Step 6: Creating VMs in parallel ==="

az vm create \
    --resource-group "$RG" \
    --name "$VM1_NAME" \
    --location "$HUB1_LOCATION" \
    --image "$IMAGE" \
    --size "$VM_SIZE" \
    --vnet-name "$SPOKE1_VNET" \
    --subnet "$SPOKE1_SUBNET" \
    --admin-username "$ADMIN_USERNAME" \
    --admin-password "$ADMIN_PASSWORD" \
    --public-ip-sku Standard \
    --nsg "" \
    --no-wait \
    --output none
check "VM 1 create (no-wait)"

az vm create \
    --resource-group "$RG" \
    --name "$VM2_NAME" \
    --location "$HUB2_LOCATION" \
    --image "$IMAGE" \
    --size "$VM_SIZE" \
    --vnet-name "$SPOKE2_VNET" \
    --subnet "$SPOKE2_SUBNET" \
    --admin-username "$ADMIN_USERNAME" \
    --admin-password "$ADMIN_PASSWORD" \
    --public-ip-sku Standard \
    --nsg "" \
    --no-wait \
    --output none
check "VM 2 create (no-wait)"

echo "Waiting for VM 1 to be created..."
az vm wait \
    --resource-group "$RG" \
    --name "$VM1_NAME" \
    --created \
    --interval 15 \
    --timeout 900
check "VM 1 ready"

echo "Waiting for VM 2 to be created..."
az vm wait \
    --resource-group "$RG" \
    --name "$VM2_NAME" \
    --created \
    --interval 15 \
    --timeout 900
check "VM 2 ready"

# =============================================================================
# STEP 7 – Connect Spoke VNets to their Hubs
# =============================================================================
echo ""
echo "=== Step 7: Connecting Spokes to Hubs ==="

SPOKE1_ID=$(az network vnet show \
    --resource-group "$RG" \
    --name "$SPOKE1_VNET" \
    --query id -o tsv)

SPOKE2_ID=$(az network vnet show \
    --resource-group "$RG" \
    --name "$SPOKE2_VNET" \
    --query id -o tsv)

az network vhub connection create \
    --resource-group "$RG" \
    --vhub-name "$HUB1_NAME" \
    --name "$SPOKE1_CONN" \
    --remote-vnet "$SPOKE1_ID" \
    --no-wait \
    --output none
check "Spoke 1 hub connection create"

az network vhub connection create \
    --resource-group "$RG" \
    --vhub-name "$HUB2_NAME" \
    --name "$SPOKE2_CONN" \
    --remote-vnet "$SPOKE2_ID" \
    --no-wait \
    --output none
check "Spoke 2 hub connection create"

echo "Waiting for Spoke 1 connection to complete..."
az network vhub connection wait \
    --resource-group "$RG" \
    --vhub-name "$HUB1_NAME" \
    --name "$SPOKE1_CONN" \
    --created \
    --interval 20 \
    --timeout 900
check "Spoke 1 connection ready"

echo "Waiting for Spoke 2 connection to complete..."
az network vhub connection wait \
    --resource-group "$RG" \
    --vhub-name "$HUB2_NAME" \
    --name "$SPOKE2_CONN" \
    --created \
    --interval 20 \
    --timeout 900
check "Spoke 2 connection ready"

# =============================================================================
# SUMMARY
# =============================================================================
echo ""
echo "==============================================================================="
echo " Deployment Complete!"
echo "==============================================================================="
echo ""
echo " Resource Group : $RG"
echo " Virtual WAN    : $VWAN"
echo ""
echo " Hub 1          : $HUB1_NAME  ($HUB1_LOCATION)  CIDR: $HUB1_CIDR"
echo " Hub 2          : $HUB2_NAME  ($HUB2_LOCATION)    CIDR: $HUB2_CIDR"
echo ""
echo " Spoke 1 VNet   : $SPOKE1_VNET  ($SPOKE1_CIDR)  → connected to $HUB1_NAME"
echo " Spoke 2 VNet   : $SPOKE2_VNET  ($SPOKE2_CIDR)  → connected to $HUB2_NAME"
echo ""

VM1_PIP=$(az vm list-ip-addresses \
    --resource-group "$RG" \
    --name "$VM1_NAME" \
    --query "[].virtualMachine.network.publicIpAddresses[0].ipAddress" \
    -o tsv)

VM2_PIP=$(az vm list-ip-addresses \
    --resource-group "$RG" \
    --name "$VM2_NAME" \
    --query "[].virtualMachine.network.publicIpAddresses[0].ipAddress" \
    -o tsv)

echo " VM 1 ($VM1_NAME)  Public IP : $VM1_PIP   SSH: ssh $ADMIN_USERNAME@$VM1_PIP"
echo " VM 2 ($VM2_NAME)  Public IP : $VM2_PIP   SSH: ssh $ADMIN_USERNAME@$VM2_PIP"
echo ""
echo " SSH access is restricted to: $MY_IP"
echo "==============================================================================="
