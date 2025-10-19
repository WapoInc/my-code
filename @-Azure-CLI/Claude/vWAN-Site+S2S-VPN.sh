#!/bin/bash

# # Variables from your existing configuration
# RESOURCE_GROUP="Claude-rg7"
# VWAN_NAME="Claude-vWAN"
# HUB1_NAME="Claude-vWAN-Hub-ZAN"
# HUB1_LOCATION="southafricanorth"

# # VPN Gateway (already exists)
# VPN_GATEWAY_NAME="Claude-vWAN-Hub-ZAN-VPN-GateWay"


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