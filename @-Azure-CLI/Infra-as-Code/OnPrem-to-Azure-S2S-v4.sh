#!/bin/bash

# Set variables
LOCATION="southafricanorth"
RESOURCE_GROUP="poc1-demo-rg5"
ONPREM_VNET="onprem-vnet"
AZURE_VNET="azure-vnet"
ONPREM_VNET_PREFIX="192.168.0.0/22"
AZURE_VNET_PREFIX="10.70.0.0/22"
ONPREM_SUBNET_PREFIX="192.168.1.0/24"
AZURE_SUBNET_PREFIX="10.70.1.0/24"
ONPREM_GATEWAY_SUBNET_PREFIX="192.168.0.0/27"
AZURE_GATEWAY_SUBNET_PREFIX="10.70.0.0/27"
AZURE_FIREWALL_SUBNET_PREFIX="10.70.3.0/26"
ONPREM_VM="onprem"
AZURE_VM="azure"
USERNAME="rootadmin"
PASSWORD="P@ssw0rd123!"
IMAGE="Ubuntu2204"
SHARED_KEY="AzureSharedKey123"
FIREWALL_NAME="azure-firewall"
FIREWALL_PIP_NAME="azure-firewall-pip"

# Create resource group
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create onprem VNet and subnets
az network vnet create --resource-group $RESOURCE_GROUP --name $ONPREM_VNET --address-prefix $ONPREM_VNET_PREFIX --location $LOCATION --subnet-name default --subnet-prefix $ONPREM_SUBNET_PREFIX
az network vnet subnet create --resource-group $RESOURCE_GROUP --vnet-name $ONPREM_VNET --name GatewaySubnet --address-prefix $ONPREM_GATEWAY_SUBNET_PREFIX

# Create azure VNet and subnets
az network vnet create --resource-group $RESOURCE_GROUP --name $AZURE_VNET --address-prefix $AZURE_VNET_PREFIX --location $LOCATION --subnet-name default --subnet-prefix $AZURE_SUBNET_PREFIX
az network vnet subnet create --resource-group $RESOURCE_GROUP --vnet-name $AZURE_VNET --name GatewaySubnet --address-prefix $AZURE_GATEWAY_SUBNET_PREFIX

# Create AzureFirewallSubnet
az network vnet subnet create \
  --resource-group $RESOURCE_GROUP \
  --vnet-name $AZURE_VNET \
  --name AzureFirewallSubnet \
  --address-prefix $AZURE_FIREWALL_SUBNET_PREFIX

# Create public IPs for gateways
az network public-ip create --resource-group $RESOURCE_GROUP --name onprem-gateway-pip --location $LOCATION --sku Standard --allocation-method Static
az network public-ip create --resource-group $RESOURCE_GROUP --name azure-gateway-pip --location $LOCATION --sku Standard --allocation-method Static

# Create public IP for Azure Firewall
az network public-ip create \
  --resource-group $RESOURCE_GROUP \
  --name $FIREWALL_PIP_NAME \
  --location $LOCATION \
  --sku Standard \
  --allocation-method Static

echo "Starting parallel VPN gateway deployments..."

# Create VPN gateways IN PARALLEL using background jobs
az network vnet-gateway create \
  --resource-group $RESOURCE_GROUP \
  --name onprem-gateway \
  --public-ip-addresses onprem-gateway-pip \
  --vnet $ONPREM_VNET \
  --gateway-type Vpn \
  --vpn-type RouteBased \
  --sku VpnGw1 \
  --location $LOCATION \
  --no-wait &

az network vnet-gateway create \
  --resource-group $RESOURCE_GROUP \
  --name azure-gateway \
  --public-ip-addresses azure-gateway-pip \
  --vnet $AZURE_VNET \
  --gateway-type Vpn \
  --vpn-type RouteBased \
  --sku VpnGw1 \
  --location $LOCATION \
  --no-wait &

# Start Azure Firewall deployment in parallel
echo "Starting Azure Firewall deployment..."
az network firewall create \
  --resource-group $RESOURCE_GROUP \
  --name $FIREWALL_NAME \
  --location $LOCATION \
  --sku AZFW_VNet \
  --tier Standard \
  --vnet-name $AZURE_VNET \
  --public-ip $FIREWALL_PIP_NAME \
  --no-wait &

echo "Gateway and Firewall deployments initiated. Waiting for completion..."

# Wait for both gateways to complete
az network vnet-gateway wait --resource-group $RESOURCE_GROUP --name onprem-gateway --created &
ONPREM_WAIT_PID=$!

az network vnet-gateway wait --resource-group $RESOURCE_GROUP --name azure-gateway --created &
AZURE_WAIT_PID=$!

# Wait for Azure Firewall
az network firewall wait --resource-group $RESOURCE_GROUP --name $FIREWALL_NAME --created &
FIREWALL_WAIT_PID=$!

# Wait for both wait commands to finish
wait $ONPREM_WAIT_PID
echo "✓ On-prem gateway deployment complete"

wait $AZURE_WAIT_PID
echo "✓ Azure gateway deployment complete"

wait $FIREWALL_WAIT_PID
echo "✓ Azure Firewall deployment complete"

# Create VMs in parallel
echo "Creating VMs in parallel..."
az vm create \
  --resource-group $RESOURCE_GROUP \
  --name $ONPREM_VM \
  --vnet-name $ONPREM_VNET \
  --subnet default \
  --image $IMAGE \
  --admin-username $USERNAME \
  --admin-password $PASSWORD \
  --location $LOCATION \
  --no-wait &

az vm create \
  --resource-group $RESOURCE_GROUP \
  --name $AZURE_VM \
  --vnet-name $AZURE_VNET \
  --subnet default \
  --image $IMAGE \
  --admin-username $USERNAME \
  --admin-password $PASSWORD \
  --location $LOCATION \
  --no-wait &

wait
echo "✓ VMs created"

# Get public IPs of gateways
ONPREM_PUBLIC_IP=$(az network public-ip show --resource-group $RESOURCE_GROUP --name onprem-gateway-pip --query ipAddress -o tsv)
AZURE_PUBLIC_IP=$(az network public-ip show --resource-group $RESOURCE_GROUP --name azure-gateway-pip --query ipAddress -o tsv)
FIREWALL_PUBLIC_IP=$(az network public-ip show --resource-group $RESOURCE_GROUP --name $FIREWALL_PIP_NAME --query ipAddress -o tsv)

echo "Gateway Public IPs:"
echo "  On-prem: $ONPREM_PUBLIC_IP"
echo "  Azure: $AZURE_PUBLIC_IP"
echo "  Firewall: $FIREWALL_PUBLIC_IP"

# Create local network gateways
az network local-gateway create --resource-group $RESOURCE_GROUP --name azure-local-gateway --gateway-ip-address $AZURE_PUBLIC_IP --local-address-prefixes $AZURE_VNET_PREFIX --location $LOCATION
az network local-gateway create --resource-group $RESOURCE_GROUP --name onprem-local-gateway --gateway-ip-address $ONPREM_PUBLIC_IP --local-address-prefixes $ONPREM_VNET_PREFIX --location $LOCATION

# Create VPN connections
az network vpn-connection create --resource-group $RESOURCE_GROUP --name onprem-to-azure --vnet-gateway1 onprem-gateway --local-gateway2 azure-local-gateway --shared-key $SHARED_KEY --location $LOCATION
az network vpn-connection create --resource-group $RESOURCE_GROUP --name azure-to-onprem --vnet-gateway1 azure-gateway --local-gateway2 onprem-local-gateway --shared-key $SHARED_KEY --location $LOCATION

echo "✓ VPN connections established"

# Create peer VNet and subnet
PEER_VNET="peer-vnet"
PEER_VNET_PREFIX="10.71.0.0/24"
PEER_SUBNET_NAME="subnet-1"
PEER_SUBNET_PREFIX="10.71.0.0/25"
PEER_VM="peer-vm"

az network vnet create \
  --resource-group $RESOURCE_GROUP \
  --name $PEER_VNET \
  --address-prefix $PEER_VNET_PREFIX \
  --location $LOCATION \
  --subnet-name $PEER_SUBNET_NAME \
  --subnet-prefix $PEER_SUBNET_PREFIX

# Create VM in peer VNet
az vm create \
  --resource-group $RESOURCE_GROUP \
  --name $PEER_VM \
  --vnet-name $PEER_VNET \
  --subnet $PEER_SUBNET_NAME \
  --image $IMAGE \
  --admin-username $USERNAME \
  --admin-password $PASSWORD \
  --location $LOCATION

# Get VNet IDs
PEER_VNET_ID=$(az network vnet show --resource-group $RESOURCE_GROUP --name $PEER_VNET --query id -o tsv)
AZURE_VNET_ID=$(az network vnet show --resource-group $RESOURCE_GROUP --name $AZURE_VNET --query id -o tsv)

# Peer peer-vnet to azure-vnet (use remote gateway)
az network vnet peering create \
  --name peer-to-azure \
  --resource-group $RESOURCE_GROUP \
  --vnet-name $PEER_VNET \
  --remote-vnet $AZURE_VNET_ID \
  --allow-vnet-access \
  --allow-forwarded-traffic \
  --use-remote-gateways

# Peer azure-vnet to peer-vnet (allow gateway transit)
az network vnet peering create \
  --name azure-to-peer \
  --resource-group $RESOURCE_GROUP \
  --vnet-name $AZURE_VNET \
  --remote-vnet $PEER_VNET_ID \
  --allow-vnet-access \
  --allow-forwarded-traffic \
  --allow-gateway-transit

echo "✓ VNet peering configured with gateway transit"
echo "Deployment complete!"