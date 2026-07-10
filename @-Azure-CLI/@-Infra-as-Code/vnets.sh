# Set variables
LOCATION="southafricanorth"
RESOURCE_GROUP="poc1-demo-rg8"
ONPREM_VNET="onprem-vnet"
AZURE_VNET="azure-vnet"
ONPREM_VNET_PREFIX="192.168.0.0/22"
ONPREM_VNET_PREFIX_2="192.168.4.0/22"  # NEW: Second CIDR block
AZURE_VNET_PREFIX="10.70.0.0/22"
ONPREM_SUBNET_PREFIX="192.168.1.0/24"
ONPREM_SUBNET_10_PREFIX="192.168.4.0/24"  # NEW: Subnet-10 prefix (corrected from 192.168.10.1/24)
AZURE_SUBNET_PREFIX="10.70.1.0/24"
ONPREM_GATEWAY_SUBNET_PREFIX="192.168.0.0/27"
AZURE_GATEWAY_SUBNET_PREFIX="10.70.0.0/27"
AZURE_FIREWALL_SUBNET_PREFIX="10.70.3.0/26"
ONPREM_VM="onprem"
ONPREM_VM_2="onprem-vm2"  # NEW: Second onprem VM name
AZURE_VM="azure"
USERNAME="rootadmin"
PASSWORD="P@ssw0rd123!"
IMAGE="Ubuntu2204"
SHARED_KEY="AzureSharedKey123"
FIREWALL_NAME="azure-firewall"
FIREWALL_PIP_NAME="azure-firewall-pip"

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