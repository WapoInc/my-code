#!/bin/bash

# Variables
RG_NAME="claude-vnet-poc-12"
LOCATION="southafricanorth"
VNET_NAME="ZA-East-vDC-vnet"

# Function to check if resource exists
resource_exists() {
    local resource_type=$1
    local name=$2
    local resource_group=$3
    
    case $resource_type in
        "group")
            az group show --name $name &>/dev/null
            ;;
        "vnet")
            az network vnet show --name $name --resource-group $resource_group &>/dev/null
            ;;
        "subnet")
            az network vnet subnet show --name $3 --vnet-name $name --resource-group $resource_group &>/dev/null
            ;;
        "public-ip")
            az network public-ip show --name $name --resource-group $resource_group &>/dev/null
            ;;
        "vnet-gateway")
            az network vnet-gateway show --name $name --resource-group $resource_group &>/dev/null
            ;;
        "local-gateway")
            az network local-gateway show --name $name --resource-group $resource_group &>/dev/null
            ;;
        "vpn-connection")
            az network vpn-connection show --name $name --resource-group $resource_group &>/dev/null
            ;;
    esac
}

# Create Resource Group
if resource_exists "group" $RG_NAME; then
    echo "Resource group $RG_NAME already exists, skipping..."
else
    echo "Creating resource group $RG_NAME..."
    az group create --name $RG_NAME --location $LOCATION
fi

# Create Virtual Network
if resource_exists "vnet" $VNET_NAME $RG_NAME; then
    echo "Virtual network $VNET_NAME already exists, skipping..."
else
    echo "Creating virtual network $VNET_NAME..."
    az network vnet create \
      --resource-group $RG_NAME \
      --name $VNET_NAME \
      --address-prefix 10.20.0.0/16 \
      --location $LOCATION
fi

# Create AzureFirewallManagementSubnet
if resource_exists "subnet" $VNET_NAME $RG_NAME "AzureFirewallManagementSubnet"; then
    echo "Subnet AzureFirewallManagementSubnet already exists, skipping..."
else
    echo "Creating subnet AzureFirewallManagementSubnet..."
    az network vnet subnet create \
      --resource-group $RG_NAME \
      --vnet-name $VNET_NAME \
      --name AzureFirewallManagementSubnet \
      --address-prefixes 10.20.7.0/24 \
      --service-endpoints Microsoft.Storage
fi

# Create AzureBastionSubnet
if resource_exists "subnet" $VNET_NAME $RG_NAME "AzureBastionSubnet"; then
    echo "Subnet AzureBastionSubnet already exists, skipping..."
else
    echo "Creating subnet AzureBastionSubnet..."
    az network vnet subnet create \
      --resource-group $RG_NAME \
      --vnet-name $VNET_NAME \
      --name AzureBastionSubnet \
      --address-prefixes 10.20.2.0/26 \
      --service-endpoints Microsoft.Storage
fi

# Create ZA-East-Subnet-1
if resource_exists "subnet" $VNET_NAME $RG_NAME "ZA-East-Subnet-1"; then
    echo "Subnet ZA-East-Subnet-1 already exists, skipping..."
else
    echo "Creating subnet ZA-East-Subnet-1..."
    az network vnet subnet create \
      --resource-group $RG_NAME \
      --vnet-name $VNET_NAME \
      --name ZA-East-Subnet-1 \
      --address-prefixes 10.20.3.0/24 \
      --service-endpoints Microsoft.Storage
fi

# Create PEP subnet
if resource_exists "subnet" $VNET_NAME $RG_NAME "PEP"; then
    echo "Subnet PEP already exists, skipping..."
else
    echo "Creating subnet PEP..."
    az network vnet subnet create \
      --resource-group $RG_NAME \
      --vnet-name $VNET_NAME \
      --name PEP \
      --address-prefixes 10.20.6.0/27 \
      --service-endpoints Microsoft.Storage
fi

# Create Ping-test subnet
if resource_exists "subnet" $VNET_NAME $RG_NAME "Ping-test"; then
    echo "Subnet Ping-test already exists, skipping..."
else
    echo "Creating subnet Ping-test..."
    az network vnet subnet create \
      --resource-group $RG_NAME \
      --vnet-name $VNET_NAME \
      --name Ping-test \
      --address-prefixes 10.20.8.0/24 \
      --service-endpoints Microsoft.Storage
fi

# Create CloudShell subnet
if resource_exists "subnet" $VNET_NAME $RG_NAME "CloudShell"; then
    echo "Subnet CloudShell already exists, skipping..."
else
    echo "Creating subnet CloudShell..."
    az network vnet subnet create \
      --resource-group $RG_NAME \
      --vnet-name $VNET_NAME \
      --name CloudShell \
      --address-prefixes 10.20.10.0/24
fi

# Create NVA subnet
if resource_exists "subnet" $VNET_NAME $RG_NAME "NVA"; then
    echo "Subnet NVA already exists, skipping..."
else
    echo "Creating subnet NVA..."
    az network vnet subnet create \
      --resource-group $RG_NAME \
      --vnet-name $VNET_NAME \
      --name NVA \
      --address-prefixes 10.20.6.32/27
fi

# Create AzureFirewallSubnet
if resource_exists "subnet" $VNET_NAME $RG_NAME "AzureFirewallSubnet"; then
    echo "Subnet AzureFirewallSubnet already exists, skipping..."
else
    echo "Creating subnet AzureFirewallSubnet..."
    az network vnet subnet create \
      --resource-group $RG_NAME \
      --vnet-name $VNET_NAME \
      --name AzureFirewallSubnet \
      --address-prefixes 10.20.6.64/26 \
      --service-endpoints Microsoft.Storage
fi

# Create AppGW-SubNet
if resource_exists "subnet" $VNET_NAME $RG_NAME "AppGW-SubNet"; then
    echo "Subnet AppGW-SubNet already exists, skipping..."
else
    echo "Creating subnet AppGW-SubNet..."
    az network vnet subnet create \
      --resource-group $RG_NAME \
      --vnet-name $VNET_NAME \
      --name AppGW-SubNet \
      --address-prefixes 10.20.9.0/24 \
      --delegations Microsoft.Network/applicationGateways
fi

# Create ZA-East-Subnet-2
if resource_exists "subnet" $VNET_NAME $RG_NAME "ZA-East-Subnet-2"; then
    echo "Subnet ZA-East-Subnet-2 already exists, skipping..."
else
    echo "Creating subnet ZA-East-Subnet-2..."
    az network vnet subnet create \
      --resource-group $RG_NAME \
      --vnet-name $VNET_NAME \
      --name ZA-East-Subnet-2 \
      --address-prefixes 10.20.5.0/24 \
      --service-endpoints Microsoft.Storage
fi

# Create OutBound-EP1
if resource_exists "subnet" $VNET_NAME $RG_NAME "OutBound-EP1"; then
    echo "Subnet OutBound-EP1 already exists, skipping..."
else
    echo "Creating subnet OutBound-EP1..."
    az network vnet subnet create \
      --resource-group $RG_NAME \
      --vnet-name $VNET_NAME \
      --name OutBound-EP1 \
      --address-prefixes 10.20.2.80/28 \
      --delegations Microsoft.Network/dnsResolvers
fi

# Create InBound-EP subnet
if resource_exists "subnet" $VNET_NAME $RG_NAME "InBound-EP"; then
    echo "Subnet InBound-EP already exists, skipping..."
else
    echo "Creating subnet InBound-EP..."
    az network vnet subnet create \
      --resource-group $RG_NAME \
      --vnet-name $VNET_NAME \
      --name InBound-EP \
      --address-prefixes 10.20.2.64/28
fi

# Create GatewaySubnet
if resource_exists "subnet" $VNET_NAME $RG_NAME "GatewaySubnet"; then
    echo "Subnet GatewaySubnet already exists, skipping..."
else
    echo "Creating subnet GatewaySubnet..."
    az network vnet subnet create \
      --resource-group $RG_NAME \
      --vnet-name $VNET_NAME \
      --name GatewaySubnet \
      --address-prefixes 10.20.0.0/24 \
      --service-endpoints Microsoft.Storage
fi

# Create ZA-East-Hub
if resource_exists "subnet" $VNET_NAME $RG_NAME "ZA-East-Hub"; then
    echo "Subnet ZA-East-Hub already exists, skipping..."
else
    echo "Creating subnet ZA-East-Hub..."
    az network vnet subnet create \
      --resource-group $RG_NAME \
      --vnet-name $VNET_NAME \
      --name ZA-East-Hub \
      --address-prefixes 10.20.1.0/24 \
      --service-endpoints Microsoft.Storage
fi

# Create Public IP for VPN Gateway
PIP_NAME="$VNET_NAME-vpn-gw-pip"
if resource_exists "public-ip" $PIP_NAME $RG_NAME; then
    echo "Public IP $PIP_NAME already exists, skipping..."
else
    echo "Creating public IP $PIP_NAME..."
    az network public-ip create \
      --resource-group $RG_NAME \
      --name $PIP_NAME \
      --allocation-method Static \
      --sku Standard \
      --location $LOCATION
fi

# Create VPN Gateway
VPN_GW_NAME="$VNET_NAME-vpn-gw"
if resource_exists "vnet-gateway" $VPN_GW_NAME $RG_NAME; then
    echo "VPN Gateway $VPN_GW_NAME already exists, skipping..."
else
    echo "Creating VPN Gateway $VPN_GW_NAME (this takes 15-45 minutes)..."
    az network vnet-gateway create \
      --resource-group $RG_NAME \
      --name $VPN_GW_NAME \
      --public-ip-address $PIP_NAME \
      --vnet $VNET_NAME \
      --gateway-type Vpn \
      --vpn-type RouteBased \
      --sku VpnGw1 \
      --location $LOCATION \
      --no-wait
fi

# Create Local Network Gateway
LNG_NAME="OnPrem-LNG"
if resource_exists "local-gateway" $LNG_NAME $RG_NAME; then
    echo "Local Network Gateway $LNG_NAME already exists, skipping..."
else
    echo "Creating Local Network Gateway $LNG_NAME..."
    az network local-gateway create \
      --resource-group $RG_NAME \
      --name $LNG_NAME \
      --gateway-ip-address 156.155.26.158 \
      --local-address-prefixes 192.168.2.0/24 \
      --location $LOCATION
fi

# Create VPN Connection
CONN_NAME="OnPrem-S2S-Connection"
if resource_exists "vpn-connection" $CONN_NAME $RG_NAME; then
    echo "VPN Connection $CONN_NAME already exists, skipping..."
else
    echo "Waiting for VPN Gateway to complete before creating connection..."
    az network vnet-gateway wait --name $VPN_GW_NAME --resource-group $RG_NAME --created
    echo "Creating VPN Connection $CONN_NAME..."
    az network vpn-connection create \
      --resource-group $RG_NAME \
      --name $CONN_NAME \
      --vnet-gateway1 $VPN_GW_NAME \
      --local-gateway2 $LNG_NAME \
      --location $LOCATION \
      --shared-key S2SPSK123!
fi

echo ""
echo "Deployment completed!"
echo "Resource Group: $RG_NAME"
echo "VNet: $VNET_NAME"
echo "VPN Gateway: $VPN_GW_NAME"
echo "Local Network Gateway: $LNG_NAME (156.155.26.158)"
echo "On-premises network: 192.168.2.0/24"
echo "VPN Connection: $CONN_NAME"