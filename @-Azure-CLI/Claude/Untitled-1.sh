#!/bin/bash
#
# Variables
RG_NAME="claude-vnet-poc2"
LOCATION="southafricanorth"
VNET_NAME="ZA-East-vDC-vnet"

# Create Resource Group
az group create --name $RG_NAME --location $LOCATION

# Create Virtual Network
az network vnet create \
  --resource-group $RG_NAME \
  --name $VNET_NAME \
  --address-prefix 10.20.0.0/16 \
  --location $LOCATION

# Create AzureFirewallManagementSubnet with service endpoints
az network vnet subnet create \
  --resource-group $RG_NAME \
  --vnet-name $VNET_NAME \
  --name AzureFirewallManagementSubnet \
  --address-prefixes 10.20.7.0/24 \
  --service-endpoints Microsoft.Storage

# Create AzureBastionSubnet with service endpoints (Note: NSG needs to be created separately)
az network vnet subnet create \
  --resource-group $RG_NAME \
  --vnet-name $VNET_NAME \
  --name AzureBastionSubnet \
  --address-prefixes 10.20.2.0/26 \
  --service-endpoints Microsoft.Storage

# Create ZA-East-Subnet-1 with service endpoints (Note: NSG needs to be created separately)
az network vnet subnet create \
  --resource-group $RG_NAME \
  --vnet-name $VNET_NAME \
  --name ZA-East-Subnet-1 \
  --address-prefixes 10.20.3.0/24 \
  --service-endpoints Microsoft.Storage

# Create PEP subnet with service endpoints
az network vnet subnet create \
  --resource-group $RG_NAME \
  --vnet-name $VNET_NAME \
  --name PEP \
  --address-prefixes 10.20.6.0/27 \
  --service-endpoints Microsoft.Storage

# Create Ping-test subnet with service endpoints (Note: NSG and NAT Gateway need to be created separately)
az network vnet subnet create \
  --resource-group $RG_NAME \
  --vnet-name $VNET_NAME \
  --name Ping-test \
  --address-prefixes 10.20.8.0/24 \
  --service-endpoints Microsoft.Storage

# Create CloudShell subnet
az network vnet subnet create \
  --resource-group $RG_NAME \
  --vnet-name $VNET_NAME \
  --name CloudShell \
  --address-prefixes 10.20.10.0/24

# Create NVA subnet
az network vnet subnet create \
  --resource-group $RG_NAME \
  --vnet-name $VNET_NAME \
  --name NVA \
  --address-prefixes 10.20.6.32/27

# Create AzureFirewallSubnet with service endpoints
az network vnet subnet create \
  --resource-group $RG_NAME \
  --vnet-name $VNET_NAME \
  --name AzureFirewallSubnet \
  --address-prefixes 10.20.6.64/26 \
  --service-endpoints Microsoft.Storage

# Create AppGW-SubNet with Application Gateway delegation
az network vnet subnet create \
  --resource-group $RG_NAME \
  --vnet-name $VNET_NAME \
  --name AppGW-SubNet \
  --address-prefixes 10.20.9.0/24 \
  --delegations Microsoft.Network/applicationGateways

# Create ZA-East-Subnet-2 with service endpoints (Note: NSG needs to be created separately)
az network vnet subnet create \
  --resource-group $RG_NAME \
  --vnet-name $VNET_NAME \
  --name ZA-East-Subnet-2 \
  --address-prefixes 10.20.5.0/24 \
  --service-endpoints Microsoft.Storage

# Create OutBound-EP1 with DNS resolver delegation
az network vnet subnet create \
  --resource-group $RG_NAME \
  --vnet-name $VNET_NAME \
  --name OutBound-EP1 \
  --address-prefixes 10.20.2.80/28 \
  --delegations Microsoft.Network/dnsResolvers

# Create InBound-EP subnet (Note: NSG needs to be created separately)
az network vnet subnet create \
  --resource-group $RG_NAME \
  --vnet-name $VNET_NAME \
  --name InBound-EP \
  --address-prefixes 10.20.2.64/28

# Create GatewaySubnet with service endpoints
az network vnet subnet create \
  --resource-group $RG_NAME \
  --vnet-name $VNET_NAME \
  --name GatewaySubnet \
  --address-prefixes 10.20.0.0/24 \
  --service-endpoints Microsoft.Storage

# Create ZA-East-Hub with service endpoints
az network vnet subnet create \
  --resource-group $RG_NAME \
  --vnet-name $VNET_NAME \
  --name ZA-East-Hub \
  --address-prefixes 10.20.1.0/24 \
  --service-endpoints Microsoft.Storage

# Create Public IP for VPN Gateway
az network public-ip create \
  --resource-group $RG_NAME \
  --name $VNET_NAME-vpn-gw-pip \
  --allocation-method Static \
  --sku Standard \
  --location $LOCATION

# Create VPN Gateway (this takes 15-45 minutes)
az network vnet-gateway create \
  --resource-group $RG_NAME \
  --name $VNET_NAME-vpn-gw \
  --public-ip-address $VNET_NAME-vpn-gw-pip \
  --vnet $VNET_NAME \
  --gateway-type Vpn \
  --vpn-type RouteBased \
  --sku VpnGw1 \
  --location $LOCATION \
  --no-wait

echo "VNet, subnets, and VPN Gateway created successfully!"
echo "Note: VPN Gateway creation is running in background and takes 15-45 minutes to complete"
echo ""
echo "IMPORTANT NOTES:"
echo "1. Network Security Groups (NSGs) referenced in the template need to be created separately"
echo "2. NAT Gateway (NAT-GW1) needs to be created and associated with Ping-test subnet"
echo "3. VNet peerings to ZA-East-Spoke-1 (10.21.0.0/22) and ZA-East-Spoke-2 (10.22.0.0/22) need to be created after those VNets exist"
echo "4. Some subnets have specific Azure service delegations that may require additional configuration"
echo ""
echo "Created in Resource Group: $RG_NAME"
echo "Location: $LOCATION"
echo "VNet Name: $VNET_NAME"