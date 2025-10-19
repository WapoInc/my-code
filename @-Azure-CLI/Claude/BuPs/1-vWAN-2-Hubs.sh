#!/bin/bash

# Use this azure az cli script and add 2 new vnets , Spoke-1 , CIDR = 10.101.10.0/24 , Spoke-2 , CIDR 10.101.11.0/24 , peer SPoke-1 to South Africa North Hub and SPoke-2 to South Africa West Hub , use the Azure Az cli script



# Azure Virtual WAN Hub Creation Script
# This script creates a Virtual WAN and two hubs in South Africa regions
# Make it executable: chmod +x vWAN-Hub2+VNETs.sh

# Variables
RESOURCE_GROUP="Claude-rg"
VWAN_NAME="Claude-vWAN"
HUB1_NAME="Claude-vWAN-Hub-ZAN"
HUB1_LOCATION="southafricanorth"
HUB1_CIDR="10.100.10.0/24"
HUB2_NAME="Claude-vWAN-Hub-ZAW"
HUB2_LOCATION="southafricawest" 
HUB2_CIDR="10.100.11.0/24"

echo "Starting Azure Virtual WAN Hub deployment..."

# Step 1: Create Resource Group (if it doesn't exist)
echo "Creating resource group: $RESOURCE_GROUP"
az group create \
    --name $RESOURCE_GROUP \
    --location $HUB1_LOCATION

# Step 2: Create Virtual WAN
echo "Creating Virtual WAN: $VWAN_NAME"
az network vwan create \
    --resource-group $RESOURCE_GROUP \
    --name $VWAN_NAME \
    --location $HUB1_LOCATION \
    --type Standard

# Step 3: Create Virtual Hub in South Africa North
echo "Creating Virtual Hub: $HUB1_NAME in $HUB1_LOCATION"
az network vhub create \
    --resource-group $RESOURCE_GROUP \
    --name $HUB1_NAME \
    --vwan $VWAN_NAME \
    --location $HUB1_LOCATION \
    --address-prefix $HUB1_CIDR \
    --sku Standard

# Step 4: Create Virtual Hub in South Africa West
echo "Creating Virtual Hub: $HUB2_NAME in $HUB2_LOCATION"
az network vhub create \
    --resource-group $RESOURCE_GROUP \
    --name $HUB2_NAME \
    --vwan $VWAN_NAME \
    --location $HUB2_LOCATION \
    --address-prefix $HUB2_CIDR \
    --sku Standard

echo "Deployment initiated. Virtual WAN hubs are being created..."
echo "Note: Hub deployment can take 15-30 minutes to complete."

# Optional: Check deployment status
echo "Checking resource group contents:"
az resource list --resource-group $RESOURCE_GROUP --output table

# Optional: Show Virtual WAN details
echo "Virtual WAN Details:"
az network vwan show --resource-group $RESOURCE_GROUP --name $VWAN_NAME --output table

echo "Script completed. Please monitor the Azure portal for deployment progress."