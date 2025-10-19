#!/bin/bash

# Azure CLI script to create Ubuntu 22.04 VM
# Make sure you're logged in: az login

# Variables - Customize these values
RESOURCE_GROUP="myResourceGroup2"
LOCATION="southafricanorth"
VM_NAME="myUbuntuVM"
VM_SIZE="Standard_B2s"
ADMIN_USERNAME="azureuser"
VNET_NAME="myVNet"
SUBNET_NAME="mySubnet"
NSG_NAME="myNSG"
PUBLIC_IP_NAME="myPublicIP"

# Create resource group
echo "Creating resource group..."
az group create \
    --name $RESOURCE_GROUP \
    --location $LOCATION

# Create virtual network and subnet
echo "Creating virtual network and subnet..."
az network vnet create \
    --resource-group $RESOURCE_GROUP \
    --name $VNET_NAME \
    --address-prefix 10.0.0.0/16 \
    --subnet-name $SUBNET_NAME \
    --subnet-prefix 10.0.1.0/24

# Create Network Security Group and rules
echo "Creating Network Security Group..."
az network nsg create \
    --resource-group $RESOURCE_GROUP \
    --name $NSG_NAME

# Allow SSH traffic
az network nsg rule create \
    --resource-group $RESOURCE_GROUP \
    --nsg-name $NSG_NAME \
    --name AllowSSH \
    --protocol tcp \
    --priority 1001 \
    --destination-port-range 22 \
    --access allow

# Create public IP
echo "Creating public IP..."
az network public-ip create \
    --resource-group $RESOURCE_GROUP \
    --name $PUBLIC_IP_NAME \
    --allocation-method Static

# Create the VM with Ubuntu 22.04
echo "Creating Ubuntu 22.04 VM..."
az vm create \
    --resource-group $RESOURCE_GROUP \
    --name $VM_NAME \
    --image Ubuntu2204 \
    --size $VM_SIZE \
    --admin-username $ADMIN_USERNAME \
    --generate-ssh-keys \
    --vnet-name $VNET_NAME \
    --subnet $SUBNET_NAME \
    --nsg $NSG_NAME \
    --public-ip-address $PUBLIC_IP_NAME

# Get the public IP address
echo "Getting VM public IP address..."
PUBLIC_IP=$(az vm show -d -g $RESOURCE_GROUP -n $VM_NAME --query publicIps -o tsv)

echo "VM created successfully!"
echo "SSH connection command: ssh $ADMIN_USERNAME@$PUBLIC_IP"
echo "VM Name: $VM_NAME"
echo "Resource Group: $RESOURCE_GROUP"
echo "Public IP: $PUBLIC_IP"