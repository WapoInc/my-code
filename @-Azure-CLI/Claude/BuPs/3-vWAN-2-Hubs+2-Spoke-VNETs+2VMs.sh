#!/bin/bash


# Variables
RESOURCE_GROUP="Claude-rg"
VM_SIZE="Standard_B2s"
ADMIN_USERNAME="rootadmin"
IMAGE="ubuntu2204"

# Spoke 1 configuration
SPOKE1_VNET="spoke-1"
SPOKE1_SUBNET="Spoke-1-Subnet"
VM1_NAME="ubuntu-spoke-1"

# Spoke 2 configuration
SPOKE2_VNET="spoke-2"
SPOKE2_SUBNET="Spoke-2-Subnet"
VM2_NAME="ubuntu-spoke-2"

echo "Getting VNet locations..."

# Get the location of spoke-1 VNet
SPOKE1_LOCATION=$(az network vnet show \
  --resource-group $RESOURCE_GROUP \
  --name $SPOKE1_VNET \
  --query location \
  --output tsv)

# Get the location of spoke-2 VNet
SPOKE2_LOCATION=$(az network vnet show \
  --resource-group $RESOURCE_GROUP \
  --name $SPOKE2_VNET \
  --query location \
  --output tsv)

echo "Spoke-1 VNet is in: $SPOKE1_LOCATION"
echo "Spoke-2 VNet is in: $SPOKE2_LOCATION"
echo ""

# Spoke 1 configuration
SPOKE1_VNET="spoke-1"
SPOKE1_SUBNET="Spoke-1-Subnet"
VM1_NAME="ubuntu-spoke-1"

# Spoke 2 configuration
SPOKE2_VNET="spoke-2"
SPOKE2_SUBNET="Spoke-2-Subnet"
VM2_NAME="ubuntu-spoke-2"

echo "Getting VNet locations..."

# Get the location of spoke-1 VNet
SPOKE1_LOCATION=$(az network vnet show \
  --resource-group $RESOURCE_GROUP \
  --name $SPOKE1_VNET \
  --query location \
  --output tsv)

# Get the location of spoke-2 VNet
SPOKE2_LOCATION=$(az network vnet show \
  --resource-group $RESOURCE_GROUP \
  --name $SPOKE2_VNET \
  --query location \
  --output tsv)

echo "Spoke-1 VNet is in: $SPOKE1_LOCATION"
echo "Spoke-2 VNet is in: $SPOKE2_LOCATION"
echo ""

# Create VM 1 in Spoke-1 VNet
echo "========================================="
echo "Creating VM: ubuntu-spoke-1"
echo "Location: $SPOKE1_LOCATION"
echo "VNet: $SPOKE1_VNET"
echo "Subnet: $SPOKE1_SUBNET"
echo "========================================="

# Create Public IP for VM1
echo "Creating Public IP for VM1..."
az network public-ip create \
  --resource-group $RESOURCE_GROUP \
  --name "${VM1_NAME}-pip" \
  --location $SPOKE1_LOCATION \
  --sku Standard \
  --allocation-method Static

if [ $? -ne 0 ]; then
    echo "Error: Failed to create Public IP for VM1"
    exit 1
fi

# Create NIC for VM1 with Public IP attached
echo "Creating NIC for VM1..."
az network nic create \
  --resource-group $RESOURCE_GROUP \
  --name "${VM1_NAME}-nic" \
  --vnet-name $SPOKE1_VNET \
  --subnet $SPOKE1_SUBNET \
  --location $SPOKE1_LOCATION \
  --public-ip-address "${VM1_NAME}-pip"

if [ $? -ne 0 ]; then
    echo "Error: Failed to create NIC for VM1"
    exit 1
fi

# Create VM1 (only specify the NIC, no network parameters)
echo "Creating VM1..."
az vm create \
  --resource-group $RESOURCE_GROUP \
  --name $VM1_NAME \
  --location $SPOKE1_LOCATION \
  --nics "${VM1_NAME}-nic" \
  --image $IMAGE \
  --size $VM_SIZE \
  --admin-username $ADMIN_USERNAME \
  --generate-ssh-keys

if [ $? -ne 0 ]; then
    echo "Error: Failed to create VM1"
    exit 1
fi

echo "VM1 created successfully!"
echo ""



# Create VM 2 in Spoke-2 VNet
echo "========================================="
echo "Creating VM: ubuntu-spoke-2"
echo "Location: $SPOKE2_LOCATION"
echo "VNet: $SPOKE2_VNET"
echo "Subnet: $SPOKE2_SUBNET"
echo "========================================="

# Create Public IP for VM2
echo "Creating Public IP for VM2..."
az network public-ip create \
  --resource-group $RESOURCE_GROUP \
  --name "${VM2_NAME}-pip" \
  --location $SPOKE2_LOCATION \
  --sku Standard \
  --allocation-method Static



# Create NIC for VM2 with Public IP attached
echo "Creating NIC for VM2..."
az network nic create \
  --resource-group $RESOURCE_GROUP \
  --name "${VM2_NAME}-nic" \
  --vnet-name $SPOKE2_VNET \
  --subnet $SPOKE2_SUBNET \
  --location $SPOKE2_LOCATION \
  --public-ip-address "${VM2_NAME}-pip"


# Create VM2 (only specify the NIC, no network parameters)
echo "Creating VM2..."
az vm create \
  --resource-group $RESOURCE_GROUP \
  --name $VM2_NAME \
  --location $SPOKE2_LOCATION \
  --nics "${VM2_NAME}-nic" \
  --image $IMAGE \
  --size $VM_SIZE \
  --admin-username $ADMIN_USERNAME \
  --generate-ssh-keys



echo "VM2 created successfully!"
echo ""


echo ""
echo "Both VMs have been created successfully!"
echo ""


# Simple SSH access for both VMs
for VM in $VM1_NAME $VM2_NAME; do
    NIC=$(az vm show -g $RESOURCE_GROUP -n $VM --query "networkProfile.networkInterfaces[0].id" -o tsv | xargs basename)
    NSG="${VM}-nsg"
    az network nsg create -g $RESOURCE_GROUP -n $NSG >/dev/null 2>&1
    az network nic update -g $RESOURCE_GROUP -n $NIC --nsg $NSG >/dev/null 2>&1
    az network nsg rule create -g $RESOURCE_GROUP --nsg-name $NSG -n SSH --priority 1001 --port 22 --access Allow >/dev/null 2>&1
    echo "✓ SSH enabled for $VM"
done

echo ""
echo "ubuntu-spoke-1:"
echo "  Location: $SPOKE1_LOCATION"
echo "  VNet: $SPOKE1_VNET"
echo "  Subnet: $SPOKE1_SUBNET"
echo "  Private IP: $VM1_PRIVATE_IP"
echo "  Public IP: $VM1_PUBLIC_IP"
echo "  SSH Command: ssh ${ADMIN_USERNAME}@${VM1_PUBLIC_IP}"
echo ""
echo "ubuntu-spoke-2:"
echo "  Location: $SPOKE2_LOCATION"
echo "  VNet: $SPOKE2_VNET"
echo "  Subnet: $SPOKE2_SUBNET"
echo "  Private IP: $VM2_PRIVATE_IP"
echo "  Public IP: $VM2_PUBLIC_IP"
echo "  SSH Command: ssh ${ADMIN_USERNAME}@${VM2_PUBLIC_IP}"
echo ""

