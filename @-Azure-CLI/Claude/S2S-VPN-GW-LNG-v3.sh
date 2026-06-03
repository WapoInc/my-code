#!/bin/bash

# Azure Site-to-Site VPN Configuration Script
# This script creates all necessary resources for a site-to-site VPN connection

# Variables - Modify these as needed
RESOURCE_GROUP="Claude-rg5"
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

fmt_duration() {
    local secs=$1
    [ $secs -ge 60 ] && printf "%dm %ds" $((secs/60)) $((secs%60)) || printf "%ds" $secs
}

begin_resource() {
    local label="$1"
    printf "Deploying: %s...\n" "$label"
    _S=$(date +%s); _SF=$(date "+%H:%M:%S")
}

end_resource() {
    local E=$(date +%s)
    printf "  Start: %s  End: %s  Duration: %s\n\n" "$_SF" "$(date "+%H:%M:%S")" "$(fmt_duration $((E-_S)))"
}

echo "Starting Azure Site-to-Site VPN deployment..."
echo "================================================"

# Resource Group
begin_resource "Resource Group"
az group create --name $RESOURCE_GROUP --location $LOCATION > /dev/null 2>&1
end_resource

# Virtual Network
begin_resource "Virtual Network"
az network vnet create --resource-group $RESOURCE_GROUP --name $VNET_NAME --address-prefix $VNET_PREFIX --location $LOCATION > /dev/null 2>&1
end_resource

# Gateway Subnet
begin_resource "Gateway Subnet"
az network vnet subnet create --resource-group $RESOURCE_GROUP --vnet-name $VNET_NAME --name GatewaySubnet --address-prefix $GATEWAY_SUBNET_PREFIX > /dev/null 2>&1
end_resource

# Internal Subnet
begin_resource "Internal Subnet"
az network vnet subnet create --resource-group $RESOURCE_GROUP --vnet-name $VNET_NAME --name $INTERNAL_SUBNET_NAME --address-prefix $INTERNAL_SUBNET_PREFIX > /dev/null 2>&1
end_resource

# Public IP
begin_resource "Public IP (VPN Gateway)"
az network public-ip create --resource-group $RESOURCE_GROUP --name $VPN_GATEWAY_PIP_NAME --allocation-method Static --sku Standard > /dev/null 2>&1
end_resource

# VPN Gateway (30-45 min)
begin_resource "VPN Gateway"
az network vnet-gateway create --resource-group $RESOURCE_GROUP --name $VPN_GATEWAY_NAME --vnet $VNET_NAME --public-ip-address $VPN_GATEWAY_PIP_NAME --gateway-type Vpn --vpn-type RouteBased --sku VpnGw1 --no-wait > /dev/null 2>&1
az network vnet-gateway wait --resource-group $RESOURCE_GROUP --name $VPN_GATEWAY_NAME --created > /dev/null 2>&1
end_resource

# Local Network Gateway
begin_resource "Local Network Gateway"
az network local-gateway create --resource-group $RESOURCE_GROUP --name $LOCAL_GATEWAY_NAME --gateway-ip-address $LOCAL_GATEWAY_PUBLIC_IP --local-address-prefixes $LOCAL_NETWORK_PREFIX > /dev/null 2>&1
end_resource

# VPN Connection
begin_resource "VPN Connection (IPSec)"
az network vpn-connection create --resource-group $RESOURCE_GROUP --name $CONNECTION_NAME --vnet-gateway1 $VPN_GATEWAY_NAME --local-gateway2 $LOCAL_GATEWAY_NAME --shared-key $SHARED_KEY --location $LOCATION > /dev/null 2>&1
end_resource

echo "================================================"
echo "Deployment complete."
