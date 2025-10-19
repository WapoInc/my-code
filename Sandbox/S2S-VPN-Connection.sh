REGION="southafricanorth"   # Requested region
# MiaCasa
# Address spaces (must NOT overlap)
HUB_VNET_CIDR="10.10.0.0/16"
HUB_WORKLOAD_SUBNET_CIDR="10.10.1.0/24"
HUB_GW_SUBNET_CIDR="10.10.255.0/27"

ONPREM_VNET_CIDR="10.20.0.0/16"
ONPREM_WORKLOAD_SUBNET_CIDR="10.20.1.0/24"
ONPREM_GW_SUBNET_CIDR="10.20.255.0/27"

# Single Resource Group
RG_NAME="rg-network-hybrid-${ENVIRONMENT}-san"

# VNet Names
HUB_VNET_NAME="vnet-hub-${ENVIRONMENT}-san"
ONPREM_VNET_NAME="vnet-onprem-sim-${ENVIRONMENT}-san"

# Subnets
HUB_SUBNET_NAME="snet-workload"
ONPREM_SUBNET_NAME="snet-onprem-workload"
GATEWAY_SUBNET_NAME="GatewaySubnet"  # Must be exactly this for VPN Gateway

# Public IPs
