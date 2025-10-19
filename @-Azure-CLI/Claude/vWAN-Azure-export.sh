#!/bin/bash

# Azure CLI script to deploy Virtual WAN
# Converted from ARM template

# Set variables
RESOURCE_GROUP_NAME="Claude-vWAN-PoC"
LOCATION="southafricanorth"
VWAN_NAME="Claude-vWAN-ZAN"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting Azure Virtual WAN deployment...${NC}"

# Check if logged into Azure CLI
echo "Checking Azure CLI authentication..."
if ! az account show &> /dev/null; then
    echo -e "${RED}Error: Not logged into Azure CLI. Please run 'az login' first.${NC}"
    exit 1
fi

# Display current subscription
CURRENT_SUBSCRIPTION=$(az account show --query name --output tsv)
echo -e "${GREEN}Current subscription: $CURRENT_SUBSCRIPTION${NC}"

# Confirm deployment
read -p "Do you want to proceed with the deployment? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

# Check if resource group exists, create if not
echo "Checking if resource group '$RESOURCE_GROUP_NAME' exists..."
if ! az group show --name "$RESOURCE_GROUP_NAME" &> /dev/null; then
    echo -e "${YELLOW}Resource group '$RESOURCE_GROUP_NAME' does not exist. Creating...${NC}"
    az group create \
        --name "$RESOURCE_GROUP_NAME" \
        --location "$LOCATION"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Resource group created successfully.${NC}"
    else
        echo -e "${RED}Failed to create resource group.${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}Resource group '$RESOURCE_GROUP_NAME' already exists.${NC}"
fi

# Deploy Virtual WAN
echo -e "${YELLOW}Creating Virtual WAN '$VWAN_NAME'...${NC}"
az network vwan create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$VWAN_NAME" \
    --location "$LOCATION" \
    --type "Standard" \
    --allow-branch-to-branch-traffic true \
    --disable-vpn-encryption false

# Check deployment status
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Virtual WAN '$VWAN_NAME' created successfully!${NC}"
    
    # Display resource details
    echo -e "${YELLOW}Resource Details:${NC}"
    az network vwan show \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --name "$VWAN_NAME" \
        --output table
else
    echo -e "${RED}Failed to create Virtual WAN.${NC}"
    exit 1
fi

echo -e "${GREEN}Deployment completed successfully!${NC}"