#!/bin/bash
set -euo pipefail

# --- Configuration ---
RESOURCE_GROUP="rg-vm-southafrica"
LOCATION="southafricanorth"
VM_NAME="vm-ubuntu-san"
ADMIN_USERNAME="azureuser"
IMAGE="Ubuntu2404"
VM_SIZE="Standard_B2s"
PUBLIC_IP_NAME="${VM_NAME}-pip"
NSG_NAME="${VM_NAME}-nsg"
VNET_NAME="${VM_NAME}-vnet"
SUBNET_NAME="default"
NIC_NAME="${VM_NAME}-nic"

echo "==> Creating resource group: $RESOURCE_GROUP in $LOCATION"
az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION"

echo "==> Creating VNet and subnet"
az network vnet create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VNET_NAME" \
  --address-prefix "10.0.0.0/16" \
  --subnet-name "$SUBNET_NAME" \
  --subnet-prefix "10.0.0.0/24"

echo "==> Creating public IP (static)"
az network public-ip create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$PUBLIC_IP_NAME" \
  --allocation-method Static \
  --sku Standard \
  --location "$LOCATION"

echo "==> Creating NSG with SSH rule"
az network nsg create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$NSG_NAME"

az network nsg rule create \
  --resource-group "$RESOURCE_GROUP" \
  --nsg-name "$NSG_NAME" \
  --name "Allow-SSH" \
  --priority 1000 \
  --protocol Tcp \
  --destination-port-range 22 \
  --access Allow \
  --direction Inbound

echo "==> Creating NIC"
az network nic create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$NIC_NAME" \
  --vnet-name "$VNET_NAME" \
  --subnet "$SUBNET_NAME" \
  --public-ip-address "$PUBLIC_IP_NAME" \
  --network-security-group "$NSG_NAME"

echo "==> Creating VM: $VM_NAME"
az vm create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VM_NAME" \
  --nics "$NIC_NAME" \
  --image "$IMAGE" \
  --size "$VM_SIZE" \
  --admin-username "$ADMIN_USERNAME" \
  --ssh-key-values "$(cat ~/.ssh/id_rsa.pub 2>/dev/null || cat ~/.ssh/id_ed25519.pub 2>/dev/null)" \
  --location "$LOCATION" \
  --os-disk-size-gb 30

PUBLIC_IP=$(az network public-ip show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$PUBLIC_IP_NAME" \
  --query "ipAddress" \
  --output tsv)

echo ""
echo "==> VM created successfully!"
echo "    Name:       $VM_NAME"
echo "    Region:     $LOCATION"
echo "    Image:      Ubuntu 24.04"
echo "    Public IP:  $PUBLIC_IP"
echo "    SSH:        ssh ${ADMIN_USERNAME}@${PUBLIC_IP}"
