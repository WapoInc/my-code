#!/bin/bash

# Variables based on your network configuration
RESOURCE_GROUP="za-east-vdc"
LOCATION="southafricanorth"
SUBNET_NAME="Ping-test"
VNET_NAME="za-east-vdc-vnet"  # Replace with your actual VNet name if different
VM_NAME="ubuntu-ping-test-vm-1"
VM_SIZE="Standard_B2s"  # Adjust size as needed
USERNAME="rootadmin"
PASSWORD="P@ssw0rd123!"
IMAGE="Ubuntu2204"

# Create the Ubuntu VM
echo "Creating Ubuntu VM in Ping-test subnet..."

az vm create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VM_NAME" \
    --location "$LOCATION" \
    --image "$IMAGE" \
    --size "$VM_SIZE" \
    --admin-username "$USERNAME" \
    --admin-password "$PASSWORD" \
    --authentication-type password \
    --subnet "$SUBNET_NAME" \
    --vnet-name "$VNET_NAME" \
    --boot-diagnostics-storage "" \

    --public-ip-sku Standard \
    --os-disk-size-gb 30 \
    --storage-sku Standard_LRS

# Enable boot diagnostics with managed storage
echo "Enabling boot diagnostics with managed storage..."

az vm boot-diagnostics enable \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VM_NAME"

echo "VM creation completed!"
echo "VM Name: $VM_NAME"
echo "Resource Group: $RESOURCE_GROUP"
echo "Location: $LOCATION"
echo "Subnet: $SUBNET_NAME (10.20.8.0/24)"
echo "Username: $USERNAME"
echo "Boot diagnostics: Enabled with managed storage"

# Optional: Show VM details
echo "Getting VM details..."
az vm show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VM_NAME" \
    --show-details \
    --output table