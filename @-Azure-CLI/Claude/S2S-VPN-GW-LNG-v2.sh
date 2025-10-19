#!/bin/bash

# Azure Site-to-Site VPN Configuration Script
# This script creates all necessary resources for a site-to-site VPN connection

# Variables - Modify these as needed
RESOURCE_GROUP="Claude-rg4"
LOCATION="southafricanorth"
VNET_NAME="vnet-azure-hub"
VNET_PREFIX="10.50.0.0/22"
GATEWAY_SUBNET_PREFIX="10.50.0.0/27"
INTERNAL_SUBNET_NAME="subnet-internal"
INTERNAL_SUBNET_PREFIX="10.50.1.0/24"
VPN_GATEWAY_NAME="vpngw-azure-hub"
VPN_GATEWAY_PIP_NAME="pip-vpngw-hub"
LOCAL_GATEWAY_NAME="lgw-onprem"
LOCAL_GATEWAY_PUBLIC_IP="156.155.28.158"
LOCAL_NETWORK_PREFIX="192.168.2.0/24"
CONNECTION_NAME="conn-azure-to-onprem"
SHARED_KEY="Qazzaq123!"

echo "Starting Azure Site-to-Site VPN deployment..."
echo "================================================"

# Create Resource Group
echo "Creating Resource Group..."
az group create \
    --name $RESOURCE_GROUP \
    --location $LOCATION

# Create Virtual Network
echo "Creating Virtual Network..."
az network vnet create \
    --resource-group $RESOURCE_GROUP \
    --name $VNET_NAME \
    --address-prefix $VNET_PREFIX \
    --location $LOCATION

# Create Gateway Subnet (must be named 'GatewaySubnet')
echo "Creating Gateway Subnet..."
az network vnet subnet create \
    --resource-group $RESOURCE_GROUP \
    --vnet-name $VNET_NAME \
    --name GatewaySubnet \
    --address-prefix $GATEWAY_SUBNET_PREFIX

# Create Internal Subnet (optional - for VMs/resources in Azure)
echo "Creating Internal Subnet..."
az network vnet subnet create \
    --resource-group $RESOURCE_GROUP \
    --vnet-name $VNET_NAME \
    --name $INTERNAL_SUBNET_NAME \
    --address-prefix $INTERNAL_SUBNET_PREFIX

# Create Public IP for VPN Gateway
echo "Creating Public IP for VPN Gateway..."
az network public-ip create \
    --resource-group $RESOURCE_GROUP \
    --name $VPN_GATEWAY_PIP_NAME \
    --allocation-method Static \
    --sku Standard

# Create VPN Gateway (This takes 30-45 minutes!)
echo "Creating VPN Gateway (this will take 30-45 minutes)..."
az network vnet-gateway create \
    --resource-group $RESOURCE_GROUP \
    --name $VPN_GATEWAY_NAME \
    --vnet $VNET_NAME \
    --public-ip-address $VPN_GATEWAY_PIP_NAME \
    --gateway-type Vpn \
    --vpn-type RouteBased \
    --sku VpnGw1 \
    --no-wait

# Wait for VPN Gateway to be provisioned
echo "Waiting for VPN Gateway to be fully provisioned..."
az network vnet-gateway wait \
    --resource-group $RESOURCE_GROUP \
    --name $VPN_GATEWAY_NAME \
    --created

# Create Local Network Gateway (represents on-premises network)
echo "Creating Local Network Gateway..."
az network local-gateway create \
    --resource-group $RESOURCE_GROUP \
    --name $LOCAL_GATEWAY_NAME \
    --gateway-ip-address $LOCAL_GATEWAY_PUBLIC_IP \
    --local-address-prefixes $LOCAL_NETWORK_PREFIX

# Create VPN Connection (IPSec)
echo "Creating VPN Connection..."
az network vpn-connection create \
    --resource-group $RESOURCE_GROUP \
    --name $CONNECTION_NAME \
    --vnet-gateway1 $VPN_GATEWAY_NAME \
    --local-gateway2 $LOCAL_GATEWAY_NAME \
    --shared-key $SHARED_KEY \
    --location $LOCATION

