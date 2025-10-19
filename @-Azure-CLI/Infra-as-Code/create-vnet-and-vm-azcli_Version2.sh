#!/bin/bash

# Azure Infrastructure Deployment Script
# Location: South Africa North
# Resource Group: vmr-rg1
# Date: 2025-09-27

# ========================================
# CONFIGURATION VARIABLES
# ========================================
RESOURCE_GROUP="vmr-rg2"
LOCATION="southafricanorth"
VNET_NAME="vnet-san-001"
VNET_ADDRESS_PREFIX="10.28.0.0/22"

# Subnet configurations
GATEWAY_SUBNET_PREFIX="10.28.0.0/24"
SHARED_SERVICES_SUBNET_PREFIX="10.28.1.0/24"

# VM Configuration
VM_NAME="vm-ubuntu-shared-001"
VM_SIZE="Standard_B2s"
IMAGE="ubuntu2204"
ADMIN_USERNAME="rootadmin"
ADMIN_PASSWORD='P@ssw0rd123!'
NSG_NAME="nsg-shared-services"
PUBLIC_IP_NAME="pip-vm-ubuntu-001"
NIC_NAME="nic-vm-ubuntu-001"

# ========================================
# STEP 1: CREATE RESOURCE GROUP
# ========================================
echo "Creating Resource Group: $RESOURCE_GROUP"
az group create \
    --name $RESOURCE_GROUP \
    --location $LOCATION \
    --tags "Environment=Production" "CreatedDate=2025-09-27" "Owner=WapoInc"

# ========================================
# STEP 2: CREATE VIRTUAL NETWORK
# ========================================
echo "Creating Virtual Network: $VNET_NAME"
az network vnet create \
    --resource-group $RESOURCE_GROUP \
    --name $VNET_NAME \
    --address-prefix $VNET_ADDRESS_PREFIX \
    --location $LOCATION

# ========================================
# STEP 3: CREATE SUBNETS
# ========================================
echo "Creating Gateway Subnet"
az network vnet subnet create \
    --resource-group $RESOURCE_GROUP \
    --vnet-name $VNET_NAME \
    --name GatewaySubnet \
    --address-prefix $GATEWAY_SUBNET_PREFIX

echo "Creating Shared Services Subnet"
az network vnet subnet create \
    --resource-group $RESOURCE_GROUP \
    --vnet-name $VNET_NAME \
    --name SharedServicesSubnet \
    --address-prefix $SHARED_SERVICES_SUBNET_PREFIX

# ========================================
# STEP 4: CREATE NETWORK SECURITY GROUP
# ========================================
echo "Creating Network Security Group: $NSG_NAME"
az network nsg create \
    --resource-group $RESOURCE_GROUP \
    --name $NSG_NAME \
    --location $LOCATION

# Add SSH rule
az network nsg rule create \
    --resource-group $RESOURCE_GROUP \
    --nsg-name $NSG_NAME \
    --name Allow-SSH \
    --priority 1000 \
    --source-address-prefixes '*' \
    --destination-port-ranges 22 \
    --access Allow \
    --protocol Tcp \
    --direction Inbound

# Add HTTP rule
az network nsg rule create \
    --resource-group $RESOURCE_GROUP \
    --nsg-name $NSG_NAME \
    --name Allow-HTTP \
    --priority 1010 \
    --source-address-prefixes '*' \
    --destination-port-ranges 80 \
    --access Allow \
    --protocol Tcp \
    --direction Inbound

# Add HTTPS rule
az network nsg rule create \
    --resource-group $RESOURCE_GROUP \
    --nsg-name $NSG_NAME \
    --name Allow-HTTPS \
    --priority 1020 \
    --source-address-prefixes '*' \
    --destination-port-ranges 443 \
    --access Allow \
    --protocol Tcp \
    --direction Inbound

# ========================================
# STEP 5: CREATE UBUNTU VM
# ========================================
echo "Creating Ubuntu 22.04 VM: $VM_NAME"
az vm create \
    --resource-group $RESOURCE_GROUP \
    --name $VM_NAME \
    --location $LOCATION \
    --vnet-name $VNET_NAME \
    --subnet SharedServicesSubnet \
    --nsg $NSG_NAME \
    --image $IMAGE \
    --size $VM_SIZE \
    --admin-username $ADMIN_USERNAME \
    --admin-password "$ADMIN_PASSWORD" \
    --authentication-type password \
    --public-ip-address $PUBLIC_IP_NAME \
    --public-ip-sku Standard \
    --os-disk-name "${VM_NAME}-osdisk" \
    --os-disk-size-gb 30 \
    --tags "OS=Ubuntu22.04" "Purpose=SharedServices" "Owner=WapoInc"

# ========================================
# STEP 6: GET DEPLOYMENT DETAILS
# ========================================
PUBLIC_IP=$(az network public-ip show \
    --resource-group $RESOURCE_GROUP \
    --name $PUBLIC_IP_NAME \
    --query ipAddress \
    --output tsv)

PRIVATE_IP=$(az vm show \
    --resource-group $RESOURCE_GROUP \
    --name $VM_NAME \
    --show-details \
    --query privateIps \
    --output tsv)

# ========================================
# DEPLOYMENT SUMMARY
# ========================================
echo ""
echo "======================================"
echo "DEPLOYMENT COMPLETED SUCCESSFULLY!"
echo "======================================"
echo ""
echo "NETWORK CONFIGURATION:"
echo "----------------------"
echo "Resource Group:         $RESOURCE_GROUP"
echo "Location:               $LOCATION"
echo "VNet Name:              $VNET_NAME"
echo "VNet Address Space:     $VNET_ADDRESS_PREFIX"
echo "Gateway Subnet:         $GATEWAY_SUBNET_PREFIX"
echo "Shared Services Subnet: $SHARED_SERVICES_SUBNET_PREFIX"
echo ""
echo "VIRTUAL MACHINE DETAILS:"
echo "------------------------"
echo "VM Name:                $VM_NAME"
echo "VM Size:                $VM_SIZE"
echo "Operating System:       Ubuntu 22.04 LTS"
echo "Admin Username:         $ADMIN_USERNAME"
echo "Admin Password:         $ADMIN_PASSWORD"
echo "Private IP Address:     $PRIVATE_IP"
echo "Public IP Address:      $PUBLIC_IP"
echo ""
echo "SSH CONNECTION:"
echo "---------------"
echo "ssh $ADMIN_USERNAME@$PUBLIC_IP"
echo ""
echo "======================================"
ssh $ADMIN_USERNAME@$PUBLIC_IP"