#!/bin/bash
# Deploy an Ubuntu 24.04 VM in South Africa North with a public IP

# ─── Variables ───────────────────────────────────────────────────────────────
RG="rg-ubuntu-vm-southafrica"
LOCATION="southafricanorth"
VM_NAME="vm-ubuntu-southafrica"
ADMIN_USER="azureuser"
VM_SIZE="Standard_B2s"
IMAGE="Ubuntu2404"
PUBLIC_IP_NAME="pip-ubuntu-southafrica"
NSG_NAME="nsg-ubuntu-southafrica"
VNET_NAME="vnet-ubuntu-southafrica"
SUBNET_NAME="subnet-ubuntu-southafrica"

# ─── Resource Group ──────────────────────────────────────────────────────────
echo "Creating resource group: $RG"
az group create \
  --name "$RG" \
  --location "$LOCATION" \
  --output table

# ─── VNet + Subnet ───────────────────────────────────────────────────────────
echo "Creating VNet: $VNET_NAME"
az network vnet create \
  --name "$VNET_NAME" \
  --resource-group "$RG" \
  --location "$LOCATION" \
  --address-prefix "10.0.0.0/16" \
  --subnet-name "$SUBNET_NAME" \
  --subnet-prefix "10.0.1.0/24" \
  --output table

# ─── Public IP ───────────────────────────────────────────────────────────────
echo "Creating public IP: $PUBLIC_IP_NAME"
az network public-ip create \
  --name "$PUBLIC_IP_NAME" \
  --resource-group "$RG" \
  --location "$LOCATION" \
  --sku Standard \
  --allocation-method Static \
  --output table

# ─── NSG with SSH rule ────────────────────────────────────────────────────────
echo "Creating NSG: $NSG_NAME"
az network nsg create \
  --name "$NSG_NAME" \
  --resource-group "$RG" \
  --location "$LOCATION" \
  --output table

az network nsg rule create \
  --name "Allow-SSH" \
  --nsg-name "$NSG_NAME" \
  --resource-group "$RG" \
  --priority 1000 \
  --protocol Tcp \
  --direction Inbound \
  --source-address-prefixes "*" \
  --source-port-ranges "*" \
  --destination-address-prefixes "*" \
  --destination-port-ranges 22 \
  --access Allow \
  --output table

# ─── VM ──────────────────────────────────────────────────────────────────────
echo "Creating VM: $VM_NAME"
az vm create \
  --name "$VM_NAME" \
  --resource-group "$RG" \
  --location "$LOCATION" \
  --size "$VM_SIZE" \
  --image "$IMAGE" \
  --admin-username "$ADMIN_USER" \
  --generate-ssh-keys \
  --public-ip-address "$PUBLIC_IP_NAME" \
  --public-ip-sku Standard \
  --vnet-name "$VNET_NAME" \
  --subnet "$SUBNET_NAME" \
  --nsg "$NSG_NAME" \
  --output table

# ─── Output ──────────────────────────────────────────────────────────────────
PUBLIC_IP=$(az network public-ip show \
  --name "$PUBLIC_IP_NAME" \
  --resource-group "$RG" \
  --query "ipAddress" \
  --output tsv)

echo ""
echo "==========================================="
echo " VM deployment complete!"
echo " VM Name  : $VM_NAME"
echo " Region   : $LOCATION"
echo " Image    : Ubuntu 24.04"
echo " Public IP: $PUBLIC_IP"
echo " SSH      : ssh $ADMIN_USER@$PUBLIC_IP"
echo "==========================================="
