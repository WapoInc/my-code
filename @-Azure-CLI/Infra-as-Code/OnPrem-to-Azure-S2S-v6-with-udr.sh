#!/bin/bash

# Capture start time
START_TIME=$(date +%s)
START_TIMESTAMP=$(date -u '+%Y-%m-%d %H:%M:%S UTC')

echo "=========================================="
echo "Deployment Started: $START_TIMESTAMP"
echo "=========================================="
echo ""

# Set variables
LOCATION="southafricanorth"
RESOURCE_GROUP="poc1-demo-rg22"
ONPREM_VNET="onprem-vnet"
AZURE_VNET="azure-vnet"

ONPREM_VNET_PREFIX="192.168.0.0/22"
ONPREM_VNET_PREFIX_2="192.168.4.0/22"
ONPREM_SUBNET_PREFIX="192.168.1.0/24"
ONPREM_SUBNET_10_PREFIX="192.168.4.0/24"
ONPREM_GATEWAY_SUBNET_PREFIX="192.168.0.0/27"

AZURE_VNET_PREFIX="10.70.0.0/22"
AZURE_SUBNET_PREFIX="10.70.1.0/24"
AZURE_GATEWAY_SUBNET_PREFIX="10.70.0.0/27"

AZURE_FIREWALL_SUBNET_PREFIX="10.70.3.0/26"

ONPREM_VM="onprem-vm1"
ONPREM_VM_2="onprem-vm2"  # NEW: Second onprem VM name
AZURE_VM="azure-vm1"

USERNAME="adminazure"
PASSWORD="P@ssw0rd123!"
IMAGE="Ubuntu2204"
SHARED_KEY="AzureSharedKey123"
FIREWALL_NAME="azure-firewall"
FIREWALL_PIP_NAME="azure-firewall-pip"

echo "============================================================================="
# Create resource group
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create onprem VNet with BOTH address prefixes and subnets
az network vnet create \
  --resource-group $RESOURCE_GROUP \
  --name $ONPREM_VNET \
  --address-prefix $ONPREM_VNET_PREFIX $ONPREM_VNET_PREFIX_2 \
  --location $LOCATION \
  --subnet-name default \
  --subnet-prefix $ONPREM_SUBNET_PREFIX

az network vnet subnet create \
  --resource-group $RESOURCE_GROUP \
  --vnet-name $ONPREM_VNET \
  --name GatewaySubnet \
  --address-prefix $ONPREM_GATEWAY_SUBNET_PREFIX

# NEW: Create Subnet-10 in the second CIDR range
az network vnet subnet create \
  --resource-group $RESOURCE_GROUP \
  --vnet-name $ONPREM_VNET \
  --name Subnet-10 \
  --address-prefix $ONPREM_SUBNET_10_PREFIX

# Create azure VNet and subnets
az network vnet create \
  --resource-group $RESOURCE_GROUP \
  --name $AZURE_VNET \
  --address-prefix $AZURE_VNET_PREFIX \
  --location $LOCATION \
  --subnet-name default \
  --subnet-prefix $AZURE_SUBNET_PREFIX

az network vnet subnet create \
  --resource-group $RESOURCE_GROUP \
  --vnet-name $AZURE_VNET \
  --name GatewaySubnet \
  --address-prefix $AZURE_GATEWAY_SUBNET_PREFIX

# Create AzureFirewallSubnet
az network vnet subnet create \
  --resource-group $RESOURCE_GROUP \
  --vnet-name $AZURE_VNET \
  --name AzureFirewallSubnet \
  --address-prefix $AZURE_FIREWALL_SUBNET_PREFIX

# --- UDR Section: Inserted here ---
# Create a Route Table for Azure subnet
az network route-table create \
  --name azure-subnet-rt \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION

# Add route to forward 192.168.1.0/24 traffic to next hop 1.1.1.1
az network route-table route create \
  --name route-to-onprem-192-168-1-0 \
  --resource-group $RESOURCE_GROUP \
  --route-table-name azure-subnet-rt \
  --address-prefix 192.168.1.0/24 \
  --next-hop-type VirtualAppliance \
  --next-hop-ip-address 1.1.1.1

# Associate route table with Azure subnet (10.70.1.0/24)
az network vnet subnet update \
  --resource-group $RESOURCE_GROUP \
  --vnet-name $AZURE_VNET \
  --name default \
  --route-table azure-subnet-rt
# --- End UDR Section ---

# Create public IPs for gateways
az network public-ip create \
  --resource-group $RESOURCE_GROUP \
  --name onprem-gateway-pip \
  --location $LOCATION \
  --sku Standard \
  --allocation-method Static

az network public-ip create \
  --resource-group $RESOURCE_GROUP \
  --name azure-gateway-pip \
  --location $LOCATION \
  --sku Standard \
  --allocation-method Static

# Create public IP for Azure Firewall
az network public-ip create \
  --resource-group $RESOURCE_GROUP \
  --name $FIREWALL_PIP_NAME \
  --location $LOCATION \
  --sku Standard \
  --allocation-method Static

echo "============================================================================="
echo "Starting parallel VPN gateway deployments..."
echo "============================================================================="


# Capture gateway deployment start time
GATEWAY_START_TIME=$(date +%s)

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
echo "============================================================================="
echo "Starting Azure Firewall deployment..."
echo "============================================================================="


az network firewall create \
  --resource-group $RESOURCE_GROUP \
  --name $FIREWALL_NAME \
  --location $LOCATION \
  --sku AZFW_VNet \
  --tier Standard \
  --vnet-name $AZURE_VNET \
  --public-ip $FIREWALL_PIP_NAME \
  --no-wait &

echo "============================================================================="
echo "Gateway and Firewall deployments initiated. Waiting for completion..."
echo "============================================================================="

# Wait for both gateways to complete
az network vnet-gateway wait \
  --resource-group $RESOURCE_GROUP \
  --name onprem-gateway \
  --created &
ONPREM_WAIT_PID=$!

az network vnet-gateway wait \
  --resource-group $RESOURCE_GROUP \
  --name azure-gateway \
  --created &
AZURE_WAIT_PID=$!

# Wait for Azure Firewall
az network firewall wait \
  --resource-group $RESOURCE_GROUP \
  --name $FIREWALL_NAME \
  --created &
FIREWALL_WAIT_PID=$!

# Wait for both wait commands to finish
wait $ONPREM_WAIT_PID
echo "============================================================================="
echo "✓ On-prem gateway deployment complete"
echo "============================================================================="

wait $AZURE_WAIT_PID
echo "============================================================================="
echo "✓ Azure gateway deployment complete"
echo "============================================================================="

wait $FIREWALL_WAIT_PID
echo "============================================================================="
echo "✓ Azure Firewall deployment complete"
echo "============================================================================="


# Calculate gateway deployment time
GATEWAY_END_TIME=$(date +%s)
GATEWAY_DURATION=$((GATEWAY_END_TIME - GATEWAY_START_TIME))
GATEWAY_MINUTES=$((GATEWAY_DURATION / 60))
GATEWAY_SECONDS=$((GATEWAY_DURATION % 60))

echo "============================================================================="
echo "Gateway and Firewall deployment took: ${GATEWAY_MINUTES}m ${GATEWAY_SECONDS}s"
echo "============================================================================="

# Create VMs in parallel
echo "============================================================================="
echo "Creating VMs in parallel..."
echo "============================================================================="

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

# NEW: Create Ubuntu VM in Subnet-10
az vm create \
  --resource-group $RESOURCE_GROUP \
  --name $ONPREM_VM_2 \
  --vnet-name $ONPREM_VNET \
  --subnet Subnet-10 \
  --image $IMAGE \
  --admin-username $USERNAME \
  --admin-password $PASSWORD \
  --location $LOCATION \
  --no-wait &

wait
echo "============================================================================="
echo "✓ VMs created"
echo "============================================================================="

# Get public IPs of gateways
ONPREM_PUBLIC_IP=$(az network public-ip show \
  --resource-group $RESOURCE_GROUP \
  --name onprem-gateway-pip \
  --query ipAddress -o tsv)

AZURE_PUBLIC_IP=$(az network public-ip show \
  --resource-group $RESOURCE_GROUP \
  --name azure-gateway-pip \
  --query ipAddress -o tsv)

FIREWALL_PUBLIC_IP=$(az network public-ip show \
  --resource-group $RESOURCE_GROUP \
  --name $FIREWALL_PIP_NAME \
  --query ipAddress -o tsv)

echo "============================================================================="
echo "Gateway Public IPs:"
echo "============================================================================="
echo "  On-prem: $ONPREM_PUBLIC_IP"
echo "============================================================================="
echo "  Azure: $AZURE_PUBLIC_IP"
echo "============================================================================="
echo "  Firewall: $FIREWALL_PUBLIC_IP"
echo "============================================================================="


# Create local network gateways with BOTH onprem address prefixes
az network local-gateway create \
  --resource-group $RESOURCE_GROUP \
  --name azure-local-gateway \
  --gateway-ip-address $AZURE_PUBLIC_IP \
  --local-address-prefixes $AZURE_VNET_PREFIX \
  --location $LOCATION

az network local-gateway create \
  --resource-group $RESOURCE_GROUP \
  --name onprem-local-gateway \
  --gateway-ip-address $ONPREM_PUBLIC_IP \
  --local-address-prefixes $ONPREM_VNET_PREFIX $ONPREM_VNET_PREFIX_2 \
  --location $LOCATION

# Create VPN connections
az network vpn-connection create \
  --resource-group $RESOURCE_GROUP \
  --name onprem-to-azure \
  --vnet-gateway1 onprem-gateway \
  --local-gateway2 azure-local-gateway \
  --shared-key $SHARED_KEY \
  --location $LOCATION

az network vpn-connection create \
  --resource-group $RESOURCE_GROUP \
  --name azure-to-onprem \
  --vnet-gateway1 azure-gateway \
  --local-gateway2 onprem-local-gateway \
  --shared-key $SHARED_KEY \
  --location $LOCATION

echo "============================================================================="
echo "✓ VPN connections established"
echo "============================================================================="

# Get VNet IDs
PEER_VNET_ID=$(az network vnet show \
  --resource-group $RESOURCE_GROUP \
  --name $PEER_VNET \
  --query id -o tsv)

AZURE_VNET_ID=$(az network vnet show \
  --resource-group $RESOURCE_GROUP \
  --name $AZURE_VNET \
  --query id -o tsv)

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

echo "============================================================================="
echo "✓ VNet peering configured with gateway transit"
echo "============================================================================="

# Capture end time and calculate duration
END_TIME=$(date +%s)
END_TIMESTAMP=$(date -u '+%Y-%m-%d %H:%M:%S UTC')
TOTAL_DURATION=$((END_TIME - START_TIME))

# Calculate hours, minutes, and seconds
HOURS=$((TOTAL_DURATION / 3600))
MINUTES=$(((TOTAL_DURATION % 3600) / 60))
SECONDS=$((TOTAL_DURATION % 60))

echo ""
echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
echo ""
echo "Summary of changes:"
echo "  • Added second CIDR block to onprem-vnet: 192.168.4.0/22"
echo "  • Created Subnet-10: 192.168.10.0/24"
echo "  • Created new Ubuntu VM 'onprem-vm2' in Subnet-10"
echo "  • Added UDR: route 192.168.1.0/24 → next hop 1.1.1.1 for Azure subnet"
echo ""
echo "=========================================="
echo "Deployment Timeline"
echo "=========================================="
echo "Start Time:      $START_TIMESTAMP"
echo "End Time:        $END_TIMESTAMP"
echo ""
echo "Total Duration:  ${HOURS}h ${MINUTES}m ${SECONDS}s"
echo "                 ($TOTAL_DURATION seconds)"
echo "=========================================="