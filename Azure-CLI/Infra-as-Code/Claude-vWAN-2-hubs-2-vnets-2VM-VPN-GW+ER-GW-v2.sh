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
HUB1_VPN_GATEWAY_NAME="Claude-vWAN-Hub-ZAN-VPN-Gateway"
HUB1_ER_GATEWAY_NAME="Claude-vWAN-Hub-ZAN-ER-Gateway"

# Hub 2 Configuration (South Africa West)
HUB2_NAME="Claude-vWAN-Hub-ZAW"
HUB2_LOCATION="southafricanorth"     
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
# DEPLOYMENT SCRIPT
# =============================================================================

echo "==============================================================================="
echo "Starting Azure Virtual WAN Complete Deployment..."
echo "==============================================================================="

# Step 1: Create Resource Group
echo "Step 1: Creating resource group: $RESOURCE_GROUP"
az group create \
    --name $RESOURCE_GROUP \
    --location $HUB1_LOCATION

if [ $? -ne 0 ]; then
    echo "Error: Failed to create resource group"
    exit 1
fi
# =============================================================================
# Step 2: Create Virtual WAN
# =============================================================================
echo "Step 2: Creating Virtual WAN: $VWAN_NAME"
az network vwan create \
    --resource-group $RESOURCE_GROUP \
    --name $VWAN_NAME \
    --location $HUB1_LOCATION \
    --type Standard

if [ $? -ne 0 ]; then
    echo "Error: Failed to create Virtual WAN"
    exit 1
fi
# =============================================================================
# Step 3: Create Virtual Hub in South Africa North
# =============================================================================
echo "Step 3: Creating Virtual Hub: $HUB1_NAME in $HUB1_LOCATION"
az network vhub create \
    --resource-group $RESOURCE_GROUP \
    --name $HUB1_NAME \
    --vwan $VWAN_NAME \
    --location $HUB1_LOCATION \
    --address-prefix $HUB1_CIDR \
    --sku Standard

if [ $? -ne 0 ]; then
    echo "Error: Failed to create Hub 1"
    exit 1
fi
# =============================================================================
# Step 4: Create Virtual Hub in South Africa West
# =============================================================================
echo "Step 4: Creating Virtual Hub: $HUB2_NAME in $HUB2_LOCATION"
az network vhub create \
    --resource-group $RESOURCE_GROUP \
    --name $HUB2_NAME \
    --vwan $VWAN_NAME \
    --location $HUB2_LOCATION \
    --address-prefix $HUB2_CIDR \
    --sku Standard

if [ $? -ne 0 ]; then
    echo "Error: Failed to create Hub 2"
    exit 1
fi

# echo "Note: Hub deployment can take 15-30 minutes to complete. Continuing with VNet creation..."
# =============================================================================
# Step 5: Create Spoke-1 VNet
# =============================================================================
echo "Step 5: Creating Spoke VNet: $SPOKE1_VNET_NAME"
az network vnet create \
    --resource-group $RESOURCE_GROUP \
    --name $SPOKE1_VNET_NAME \
    --location $HUB1_LOCATION \
    --address-prefixes $SPOKE1_CIDR

if [ $? -ne 0 ]; then
    echo "Error: Failed to create Spoke-1 VNet"
    exit 1
fi

# Create subnet in Spoke-1
echo "Creating subnet in $SPOKE1_VNET_NAME"
az network vnet subnet create \
    --resource-group $RESOURCE_GROUP \
    --vnet-name $SPOKE1_VNET_NAME \
    --name $SPOKE1_SUBNET_NAME \
    --address-prefixes $SPOKE1_SUBNET_CIDR

# =============================================================================
# Step 6: Create Spoke-2 VNet
# =============================================================================
echo "Step 6: Creating Spoke VNet: $SPOKE2_VNET_NAME"
az network vnet create \
    --resource-group $RESOURCE_GROUP \
    --name $SPOKE2_VNET_NAME \
    --location $HUB2_LOCATION \
    --address-prefixes $SPOKE2_CIDR

if [ $? -ne 0 ]; then
    echo "Error: Failed to create Spoke-2 VNet"
    exit 1
fi

# Create subnet in Spoke-2
echo "Creating subnet in $SPOKE2_VNET_NAME"
az network vnet subnet create \
    --resource-group $RESOURCE_GROUP \
    --vnet-name $SPOKE2_VNET_NAME \
    --name $SPOKE2_SUBNET_NAME \
    --address-prefixes $SPOKE2_SUBNET_CIDR

# =============================================================================
# Step 7: Create VM 1 in Spoke-1 VNet
# =============================================================================
echo "========================================="
echo "Step 7: Creating VM: $VM1_NAME"
echo "Location: $HUB1_LOCATION"
echo "VNet: $SPOKE1_VNET_NAME"
echo "Subnet: $SPOKE1_SUBNET_NAME"
echo "========================================="

# Create Public IP for VM1
echo "Creating Public IP for VM1..."
az network public-ip create \
  --resource-group $RESOURCE_GROUP \
  --name "${VM1_NAME}-pip" \
  --location $HUB1_LOCATION \
  --sku Standard \
  --allocation-method Static

if [ $? -ne 0 ]; then
    echo "Error: Failed to create Public IP for VM1"
    exit 1
fi

# Create NIC for VM1
echo "Creating NIC for VM1..."
az network nic create \
  --resource-group $RESOURCE_GROUP \
  --name "${VM1_NAME}-nic" \
  --vnet-name $SPOKE1_VNET_NAME \
  --subnet $SPOKE1_SUBNET_NAME \
  --location $HUB1_LOCATION \
  --public-ip-address "${VM1_NAME}-pip"

if [ $? -ne 0 ]; then
    echo "Error: Failed to create NIC for VM1"
    exit 1
fi

# Create VM1
echo "Creating VM1..."
az vm create \
  --resource-group $RESOURCE_GROUP \
  --name $VM1_NAME \
  --location $HUB1_LOCATION \
  --nics "${VM1_NAME}-nic" \
  --image $IMAGE \
  --size $VM_SIZE \
  --admin-username $ADMIN_USERNAME \
  --admin-password $ADMIN_PASSWORD \
  --authentication-type password

if [ $? -ne 0 ]; then
    echo "Error: Failed to create VM1"
    exit 1
fi

echo "VM1 created successfully!"

=============================================================================
Step 8: Create VM 2 in Spoke-2 VNet
=============================================================================
echo "========================================="
echo "Step 8: Creating VM: $VM2_NAME"
echo "Location: $HUB2_LOCATION"
echo "VNet: $SPOKE2_VNET_NAME"
echo "Subnet: $SPOKE2_SUBNET_NAME"
echo "========================================="

# Create Public IP for VM2
echo "Creating Public IP for VM2..."
az network public-ip create \
  --resource-group $RESOURCE_GROUP \
  --name "${VM2_NAME}-pip" \
  --location $HUB2_LOCATION \
  --sku Standard \
  --allocation-method Static

if [ $? -ne 0 ]; then
    echo "Error: Failed to create Public IP for VM2"
    exit 1
fi

# Create NIC for VM2
echo "Creating NIC for VM2..."
az network nic create \
  --resource-group $RESOURCE_GROUP \
  --name "${VM2_NAME}-nic" \
  --vnet-name $SPOKE2_VNET_NAME \
  --subnet $SPOKE2_SUBNET_NAME \
  --location $HUB2_LOCATION \
  --public-ip-address "${VM2_NAME}-pip"

if [ $? -ne 0 ]; then
    echo "Error: Failed to create NIC for VM2"
    exit 1
fi

# Create VM2
echo "Creating VM2..."
az vm create \
  --resource-group $RESOURCE_GROUP \
  --name $VM2_NAME \
  --location $HUB2_LOCATION \
  --nics "${VM2_NAME}-nic" \
  --image $IMAGE \
  --size $VM_SIZE \
  --admin-username $ADMIN_USERNAME \
  --admin-password $ADMIN_PASSWORD \
  --authentication-type password

if [ $? -ne 0 ]; then
    echo "Error: Failed to create VM2"
    exit 1
fi

echo "VM2 created successfully!"


for VM in $VM1_NAME $VM2_NAME; do
    NIC=$(az vm show -g $RESOURCE_GROUP -n $VM --query "networkProfile.networkInterfaces[0].id" -o tsv | xargs basename)
    NSG="${VM}-nsg"
    
    echo "Creating NSG for $VM..."
    az network nsg create -g $RESOURCE_GROUP -n $NSG >/dev/null 2>&1
    az network nic update -g $RESOURCE_GROUP -n $NIC --nsg $NSG >/dev/null 2>&1
    az network nsg rule create -g $RESOURCE_GROUP --nsg-name $NSG -n SSH --priority 1001 --port 22 --access Allow >/dev/null 2>&1
    echo "✓ SSH enabled for $VM"
done
# =============================================================================
# Step 10: Create VNet connections (peering) to hubs
# =============================================================================
echo "Step 10: Creating VNet connections..."

echo "Waiting for hubs to be fully deployed before creating connections..."
echo "This may take a few minutes..."

# Wait for hubs to be ready
while true; do
    HUB1_STATE=$(az network vhub show --resource-group $RESOURCE_GROUP --name $HUB1_NAME --query provisioningState -o tsv 2>/dev/null)
    HUB2_STATE=$(az network vhub show --resource-group $RESOURCE_GROUP --name $HUB2_NAME --query provisioningState -o tsv 2>/dev/null)
    
    if [[ "$HUB1_STATE" == "Succeeded" && "$HUB2_STATE" == "Succeeded" ]]; then
        echo "Both hubs are ready!"
        break
    fi
    echo "Waiting for hubs to complete deployment... (Hub1: $HUB1_STATE, Hub2: $HUB2_STATE)"
    sleep 30
done

echo "Creating VNet connection: $SPOKE1_VNET_NAME to $HUB1_NAME"
az network vhub connection create \
    --resource-group $RESOURCE_GROUP \
    --vhub-name $HUB1_NAME \
    --name "${SPOKE1_VNET_NAME}-connection" \
    --remote-vnet $(az network vnet show --resource-group $RESOURCE_GROUP --name $SPOKE1_VNET_NAME --query id -o tsv) \
    --internet-security true

echo "Creating VNet connection: $SPOKE2_VNET_NAME to $HUB2_NAME"
az network vhub connection create \
    --resource-group $RESOURCE_GROUP \
    --vhub-name $HUB2_NAME \
    --name "${SPOKE2_VNET_NAME}-connection" \
    --remote-vnet $(az network vnet show --resource-group $RESOURCE_GROUP --name $SPOKE2_VNET_NAME --query id -o tsv) \
    --internet-security true

# =============================================================================================================================================================
# Create VPN Gateway for Primary Hub
# az network vpn-gateway create --resource-group Claude-rg2 --name testvpngw --location southafricanorth --vhub Claude-vWAN-Hub-ZAN -o table
# =============================================================================================================================================================
az network vpn-gateway create --resource-group "$RESOURCE_GROUP" --name "$HUB1_VPN_GATEWAY_NAME" --vhub "$HUB1_NAME" --location "$HUB1_LOCATION"

# =============================================================================================================================================================
# Create ExpressRoute Gateway for Primary Hub
# =============================================================================================================================================================
az network express-route gateway create --resource-group "$RESOURCE_GROUP" --name "$HUB1_ER_GATEWAY_NAME" --location "$HUB1_LOCATION" --virtual-hub "$HUB1_NAME"


# =============================================================================================================================================================
# Site-to-Site VPN Configuration
# =============================================================================================================================================================
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