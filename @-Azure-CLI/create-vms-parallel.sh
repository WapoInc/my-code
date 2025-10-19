#!/bin/bash

# Azure CLI Script to Create 4 Ubuntu 22.04 VMs in Parallel
# Region: South Africa North
# Username: azureadmin
# Authentication: SSH Keys

set -e

# Configuration
RESOURCE_GROUP="rg-ubuntu-vms3"
LOCATION="southafricanorth"
USERNAME="azureadmin"
SSH_KEY_PATH="$HOME/.ssh/id_rsa.pub"  # Path to your public SSH key
VM_COUNT=4
VM_PREFIX="ubuntu-vm"
VNET_NAME="vnet-ubuntu"
SUBNET_NAME="subnet-ubuntu"
NSG_NAME="nsg-ubuntu"
VM_SIZE="Standard_B2s"  # Explicit VM size to prevent warning
UBUNTU_IMAGE="Ubuntu2204"  # Explicit Ubuntu 22.04 image

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Verify prerequisites
echo -e "${YELLOW}[INFO]${NC} Verifying prerequisites..."

if ! command -v az &> /dev/null; then
    echo -e "${RED}[ERROR]${NC} Azure CLI is not installed. Please install it first."
    exit 1
fi

if [ ! -f "$SSH_KEY_PATH" ]; then
    echo -e "${RED}[ERROR]${NC} SSH public key not found at $SSH_KEY_PATH"
    echo -e "${YELLOW}[INFO]${NC} Generating new SSH key..."
    ssh-keygen -t rsa -b 4096 -f "$HOME/.ssh/id_rsa" -N ""
fi

echo -e "${GREEN}[SUCCESS]${NC} Prerequisites verified."

# Create resource group
echo -e "${YELLOW}[INFO]${NC} Creating resource group: $RESOURCE_GROUP in $LOCATION..."
az group create \
    --name "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --output none

echo -e "${GREEN}[SUCCESS]${NC} Resource group created."

# Create virtual network and subnet
echo -e "${YELLOW}[INFO]${NC} Creating virtual network and subnet..."
az network vnet create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VNET_NAME" \
    --address-prefix 10.0.0.0/16 \
    --subnet-name "$SUBNET_NAME" \
    --subnet-prefix 10.0.0.0/24 \
    --output none

echo -e "${GREEN}[SUCCESS]${NC} Virtual network created."

# Create Network Security Group
echo -e "${YELLOW}[INFO]${NC} Creating Network Security Group..."
az network nsg create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$NSG_NAME" \
    --output none

# Add NSG rule for SSH
az network nsg rule create \
    --resource-group "$RESOURCE_GROUP" \
    --nsg-name "$NSG_NAME" \
    --name "AllowSSH" \
    --priority 1000 \
    --direction Inbound \
    --access Allow \
    --protocol Tcp \
    --destination-port-ranges 22 \
    --source-address-prefixes '*' \
    --output none

echo -e "${GREEN}[SUCCESS]${NC} Network Security Group created."

# Function to create a single VM
create_vm() {
    local vm_number=$1
    local vm_name="${VM_PREFIX}-${vm_number}"
    local nic_name="${vm_name}-nic"
    
    echo -e "${YELLOW}[INFO - VM $vm_number]${NC} Creating VM: $vm_name..."
    
    # Create network interface
    az network nic create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$nic_name" \
        --vnet-name "$VNET_NAME" \
        --subnet "$SUBNET_NAME" \
        --network-security-group "$NSG_NAME" \
        --output none
    
    # Create VM with SSH key
    az vm create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$vm_name" \
        --nics "$nic_name" \
        --image "$UBUNTU_IMAGE" \
        --size "$VM_SIZE" \
        --admin-username "$USERNAME" \
        --ssh-key-values "$SSH_KEY_PATH" \
        --os-disk-name "${vm_name}-osdisk" \
        --os-disk-size-gb 30 \
        --output none
    
    echo -e "${GREEN}[SUCCESS - VM $vm_number]${NC} VM created: $vm_name"
}

# Create VMs in parallel
echo -e "${YELLOW}[INFO]${NC} Creating $VM_COUNT Ubuntu VMs in parallel..."
echo -e "${YELLOW}[INFO]${NC} Image: $UBUNTU_IMAGE | Size: $VM_SIZE"
echo ""

for ((i=1; i<=VM_COUNT; i++)); do
    create_vm "$i" &
done

# Wait for all background jobs to complete
wait
echo ""
echo -e "${GREEN}[SUCCESS]${NC} All VMs created successfully!"

# Display VM information
echo ""
echo -e "${YELLOW}[INFO]${NC} VM Information:"
echo ""
az vm list-ip-addresses \
    --resource-group "$RESOURCE_GROUP" \
    --output table

echo ""
echo -e "${GREEN}[SUMMARY]${NC}"
echo "Resource Group: $RESOURCE_GROUP"
echo "Location: $LOCATION"
echo "VMs Created: $VM_COUNT"
echo "Ubuntu Image: $UBUNTU_IMAGE"
echo "VM Size: $VM
