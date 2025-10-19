#!/bin/bash

# =============================================================================
# Claude-WAN.sh - Complete Azure Virtual WAN Deployment Script
# =============================================================================
# This script creates:
# - Virtual WAN with 2 hubs in South Africa region SA North and SA West
# - VPN Gateway + ER Gateway
# - 2 spoke VNets with subnets
# - 2 Ubuntu VMs (one in each spoke)
# - VNet connections (peering) between spokes and hubs
# - Create Site
# - Create S2S VPN
#
# Make it executable: chmod +x Claude-WAN.sh
# =============================================================================

# =============================================================================
# VARIABLES SECTION
# =============================================================================

# Resource Group and Virtual WAN Configuration
RESOURCE_GROUP="Claude-rg1"
VWAN_NAME="Claude-vWAN"

# Hub 1 Configuration (South Africa North)
HUB1_NAME="Claude-vWAN-Hub-ZAN"
HUB1_LOCATION="southafricanorth"
HUB1_CIDR="10.100.10.0/24"

# Hub 2 Configuration (South Africa West)
HUB2_NAME="Claude-vWAN-Hub-ZAW"
HUB2_LOCATION="southafricawest" 
HUB2_CIDR="10.100.11.0/24"

# Spoke 1 VNet Configuration
SPOKE1_VNET_NAME="Spoke-1"
SPOKE1_CIDR="10.101.10.0/24"
SPOKE1_SUBNET_NAME="Spoke-1-Subnet"
SPOKE1_SUBNET_CIDR="10.101.10.0/25"

# Spoke 2 VNet Configuration
SPOKE2_VNET_NAME="Spoke-2"
SPOKE2_CIDR="10.101.11.0/24"
SPOKE2_SUBNET_NAME="Spoke-2-Subnet"
SPOKE2_SUBNET_CIDR="10.101.11.0/25"

# VM Configuration
VM_SIZE="Standard_B2s"
ADMIN_USERNAME="rootadmin"
ADMIN_PASSWORD="P@ssw0rd123!"
IMAGE="ubuntu2204"
VM1_NAME="ubuntu-spoke-1"
VM2_NAME="ubuntu-spoke-2"


# =============================================================================
# Create VPN Gateway for Primary Hub
# =============================================================================
az network vpn-gateway create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$HUB1_NAME-VPN-Gateway" \
    --vhub "$HUB1_NAME" \
    --location "$HUB1_LOCATION"
# =============================================================================
# Create ExpressRoute Gateway for Primary Hub
# =============================================================================
az network express-route gateway create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$HUB1_NAME-ER-Gateway" \
    --virtual-hub "$HUB1_NAME" \
    --location "$HUB1_LOCATION"


# =============================================================================
# Site-to-Site VPN Configuration
# =============================================================================
SITE_NAME="MiaCasa-Site"
LINK_NAME="MK-300"
ONPREM_PUBLIC_IP="169.1.100.233"
ONPREM_CIDR="192.168.88.0/24"
PSK="S2SPSK123!"

echo "Creating Site-to-Site VPN configuration for vWAN Hub..."

# Step 1: Create VPN Site
echo "Creating VPN Site: $SITE_NAME"
az network vpn-site create \
    --resource-group $RESOURCE_GROUP \
    --name $SITE_NAME \
    --location $HUB1_LOCATION \
    --virtual-wan $VWAN_NAME \
    --ip-address $ONPREM_PUBLIC_IP \
    --address-prefixes $ONPREM_CIDR \
    --device-model "Generic" \
    --device-vendor "Generic" \
    --link-speed 100

# Step 2: Create VPN Connection from Hub to Site
echo "Creating VPN Connection: $LINK_NAME"
az network vpn-gateway connection create \
    --resource-group $RESOURCE_GROUP \
    --gateway-name $VPN_GATEWAY_NAME \
    --name $LINK_NAME \
    --remote-vpn-site $SITE_NAME \
    --shared-key $PSK \
    --protocol-type IKEv2 \
    --connection-bandwidth 100 \
    --enable-bgp false \
    --routing-weight 10

# Step 3: Verify the configuration
echo "Verifying VPN Site configuration..."
az network vpn-site show \
    --resource-group $RESOURCE_GROUP \
    --name $SITE_NAME \
    --query "{name:name, ipAddress:ipAddress, addressPrefixes:addressPrefixes, location:location}" \
    --output table

echo "Verifying VPN Connection configuration..."
az network vpn-gateway connection show \
    --resource-group $RESOURCE_GROUP \
    --gateway-name $VPN_GATEWAY_NAME \
    --name $LINK_NAME \
    --query "{name:name, connectionStatus:connectionStatus, sharedKey:sharedKey, protocol:vpnConnectionProtocolType}" \
    --output table

# Step 4: Get connection details for on-premises configuration
echo "Getting Azure VPN Gateway public IP addresses for on-premises configuration..."
az network vpn-gateway show \
    --resource-group $RESOURCE_GROUP \
    --name $VPN_GATEWAY_NAME \
    --query "bgpSettings.bgpPeeringAddresses[].tunnelIpAddresses" \
    --output table


echo "Site-to-Site VPN configuration completed!"
echo ""
echo "Next steps:"
echo "1. Configure your on-premises VPN device with the following:"
echo "   - Remote Gateway IP: Use the IP addresses shown above"
echo "   - Pre-shared Key: $PSK"
echo "   - Local Network: $ONPREM_CIDR"
echo "   - Protocol: IKEv2"
echo "2. Ensure your on-premises firewall allows VPN traffic"
echo "3. Test connectivity once both sides are configured"
echo ""
echo "To check connection status later, run:"
echo "az network vpn-gateway connection show --resource-group $RESOURCE_GROUP --gateway-name $VPN_GATEWAY_NAME --name $LINK_NAME --query connectionStatus"



# Step 11: Get VM IP addresses for summary
echo "Step 11: Gathering deployment information..."

VM1_PUBLIC_IP=$(az network public-ip show --resource-group $RESOURCE_GROUP --name "${VM1_NAME}-pip" --query ipAddress -o tsv)
VM2_PUBLIC_IP=$(az network public-ip show --resource-group $RESOURCE_GROUP --name "${VM2_NAME}-pip" --query ipAddress -o tsv)

VM1_PRIVATE_IP=$(az vm show -d --resource-group $RESOURCE_GROUP --name $VM1_NAME --query privateIps -o tsv)
VM2_PRIVATE_IP=$(az vm show -d --resource-group $RESOURCE_GROUP --name $VM2_NAME --query privateIps -o tsv)

# =============================================================================
# DEPLOYMENT SUMMARY
# =============================================================================

echo ""
echo "==============================================================================="
echo "                        DEPLOYMENT COMPLETED SUCCESSFULLY!"
echo "==============================================================================="
echo ""
echo "=== DEPLOYMENT SUMMARY ==="
echo "Resource Group: $RESOURCE_GROUP"
echo "Virtual WAN: $VWAN_NAME"
echo ""
echo "Hubs:"
echo "  - $HUB1_NAME ($HUB1_LOCATION) - $HUB1_CIDR"
echo "  - $HUB2_NAME ($HUB2_LOCATION) - $HUB2_CIDR"
echo ""
echo "Spoke VNets:"
echo "  - $SPOKE1_VNET_NAME ($HUB1_LOCATION) - $SPOKE1_CIDR -> Connected to $HUB1_NAME"
echo "  - $SPOKE2_VNET_NAME ($HUB2_LOCATION) - $SPOKE2_CIDR -> Connected to $HUB2_NAME"
echo ""
echo "Virtual Machines:"
echo "  $VM1_NAME:"
echo "    Location: $HUB1_LOCATION"
echo "    VNet: $SPOKE1_VNET_NAME"
echo "    Subnet: $SPOKE1_SUBNET_NAME"
echo "    Private IP: $VM1_PRIVATE_IP"
echo "    Public IP: $VM1_PUBLIC_IP"
echo "    SSH Command: ssh ${ADMIN_USERNAME}@${VM1_PUBLIC_IP}"
echo ""
echo "  $VM2_NAME:"
echo "    Location: $HUB2_LOCATION"
echo "    VNet: $SPOKE2_VNET_NAME"
echo "    Subnet: $SPOKE2_SUBNET_NAME"
echo "    Private IP: $VM2_PRIVATE_IP"
echo "    Public IP: $VM2_PUBLIC_IP"
echo "    SSH Command: ssh ${ADMIN_USERNAME}@${VM2_PUBLIC_IP}"
echo ""
echo "==============================================================================="
echo "All resources have been created and configured successfully!"
echo "You can now SSH into the VMs and test connectivity between them."
echo "==============================================================================="

# Optional: Display resource list
echo ""
echo "Resource Group Contents:"
az resource list --resource-group $RESOURCE_GROUP --output table

echo ""
echo "Script execution completed!"