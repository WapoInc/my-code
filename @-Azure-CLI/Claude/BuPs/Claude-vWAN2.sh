#!/bin/bash

# Set variables - UPDATE THESE VALUES
RESOURCE_GROUP_NAME="Claude-rg4"
LOCATION="southafricanorth"
VWAN_NAME="AVS-vWAN-Transit-Hub"
HUB1_NAME="AVS-Hub-Primary"
HUB2_NAME="AVS-Hub-Secondary"
ADDRESS_PREFIX_HUB1="10.0.0.0/24"
ADDRESS_PREFIX_HUB2="10.1.0.0/24"

# Create resource group
az group create --name "$RESOURCE_GROUP_NAME" --location "$LOCATION"

# Create Virtual WAN
az network vwan create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$VWAN_NAME" \
    --location "$LOCATION" \
    --type "Standard" \
    --disable-vpn-encryption false

# Create first virtual hub
az network vhub create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$HUB1_NAME" \
    --vwan "$VWAN_NAME" \
    --location "$LOCATION" \
    --address-prefix "$ADDRESS_PREFIX_HUB1"

# Create second virtual hub
az network vhub create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$HUB2_NAME" \
    --vwan "$VWAN_NAME" \
    --location "$LOCATION" \
    --address-prefix "$ADDRESS_PREFIX_HUB2"

# Create VPN Gateway for Primary Hub
az network vpn-gateway create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$HUB1_NAME-VPN-Gateway" \
    --vhub "$HUB1_NAME" \
    --location "$LOCATION"

# Create ExpressRoute Gateway for Primary Hub
az network express-route gateway create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$HUB1_NAME-ER-Gateway" \
    --virtual-hub "$HUB1_NAME" \
    --location "$LOCATION" \

echo "Deployment complete!"