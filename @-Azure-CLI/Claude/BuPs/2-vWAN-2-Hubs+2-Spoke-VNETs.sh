#!/bin/bash

# Azure Virtual WAN Hub Creation Script with Spoke VNets
# This script creates a Virtual WAN, two hubs in South Africa regions, and two spoke VNets
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

# Spoke VNet Variables
SPOKE1_VNET_NAME="Spoke-1"
SPOKE1_CIDR="10.101.10.0/24"
SPOKE1_SUBNET_NAME="Spoke-1-Subnet"
SPOKE1_SUBNET_CIDR="10.101.10.0/25"

SPOKE2_VNET_NAME="Spoke-2"
SPOKE2_CIDR="10.101.11.0/24"
SPOKE2_SUBNET_NAME="Spoke-2-Subnet"
SPOKE2_SUBNET_CIDR="10.101.11.0/25"



# Step 5: Create Spoke-1 VNet (to be peered with South Africa North Hub)
echo "Creating Spoke VNet: $SPOKE1_VNET_NAME"
az network vnet create \
    --resource-group $RESOURCE_GROUP \
    --name $SPOKE1_VNET_NAME \
    --location $HUB1_LOCATION \
    --address-prefixes $SPOKE1_CIDR

# Create subnet in Spoke-1
echo "Creating subnet in $SPOKE1_VNET_NAME"
az network vnet subnet create \
    --resource-group $RESOURCE_GROUP \
    --vnet-name $SPOKE1_VNET_NAME \
    --name $SPOKE1_SUBNET_NAME \
    --address-prefixes $SPOKE1_SUBNET_CIDR

# Step 6: Create Spoke-2 VNet (to be peered with South Africa West Hub)
echo "Creating Spoke VNet: $SPOKE2_VNET_NAME"
az network vnet create \
    --resource-group $RESOURCE_GROUP \
    --name $SPOKE2_VNET_NAME \
    --location $HUB2_LOCATION \
    --address-prefixes $SPOKE2_CIDR

# Create subnet in Spoke-2
echo "Creating subnet in $SPOKE2_VNET_NAME"
az network vnet subnet create \
    --resource-group $RESOURCE_GROUP \
    --vnet-name $SPOKE2_VNET_NAME \
    --name $SPOKE2_SUBNET_NAME \
    --address-prefixes $SPOKE2_SUBNET_CIDR

# Step 7: Create VNet connections (peering) to hubs
echo "Creating VNet connection: $SPOKE1_VNET_NAME to $HUB1_NAME"
az network vhub connection create \
    --resource-group $RESOURCE_GROUP \
    --vhub-name $HUB1_NAME \
    --name "${SPOKE1_VNET_NAME}-connection" \
    --remote-vnet $(az network vnet show --resource-group $RESOURCE_GROUP --name $SPOKE1_VNET_NAME --query id -o tsv) \
    --internet-security true

echo "Creating VNet connection: $SPOKE2_VNET_NAME to $HUB2_NAME"
az network vhub connection create \
    --resource-group $RESOURCE_GROUP \
    --vhub-name $HUB2_NAME \
    --name "${SPOKE2_VNET_NAME}-connection" \
    --remote-vnet $(az network vnet show --resource-group $RESOURCE_GROUP --name $SPOKE2_VNET_NAME --query id -o tsv) \
    --internet-security true

echo "Deployment completed successfully!"

# Display summary
echo ""
echo "=== DEPLOYMENT SUMMARY ==="
echo "Resource Group: $RESOURCE_GROUP"
echo "Virtual WAN: $VWAN_NAME"
echo ""
echo "Hubs:"
echo "  - $HUB1_NAME ($HUB1_LOCATION) - $HUB1_CIDR"
echo "  - $HUB2_NAME ($HUB2_LOCATION) - $HUB2_CIDR"
echo ""
echo "Spoke VNets:"
echo "  - $SPOKE1_VNET_NAME ($HUB1_LOCATION) - $SPOKE1_CIDR -> Connected to $HUB1_NAME"
echo "  - $SPOKE2_VNET_NAME ($HUB2_LOCATION) - $SPOKE2_CIDR -> Connected to $HUB2_NAME"
echo ""

# Optional: Check deployment status
echo "Checking resource group contents:"
az resource list --resource-group $RESOURCE_GROUP --output table

# Optional: Show Virtual WAN details
echo ""
echo "Virtual WAN Details:"
az network vwan show --resource-group $RESOURCE_GROUP --name $VWAN_NAME --output table

# Show VNet connections
echo ""
echo "VNet Connections:"
az network vhub connection list --resource-group $RESOURCE_GROUP --vhub-name $HUB1_NAME --output table
az network vhub connection list --resource-group $RESOURCE_GROUP --vhub-name $HUB2_NAME --output table

echo ""
echo "Script completed successfully!"
echo "All resources have been created and configured."