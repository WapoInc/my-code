#!/bin/bash

# ExpressRoute Connection Script
# This script connects the ExpressRoute Gateway to the ExpressRoute Circuit

# Gateway Configuration (from your existing deployment)
RESOURCE_GROUP="Claude-rg4"
EXPRESSROUTE_GATEWAY_NAME="zaw-ergw-azure-hub"

# ExpressRoute Circuit Configuration
CIRCUIT_RESOURCE_GROUP="ER-LTSA-RG"
CIRCUIT_NAME="ER-LIT-SA-North"

# Connection Configuration
CONNECTION_NAME="zaw-er-connection-hub"
RESOURCE_GROUP="Claude-rg4"  # Creating connection in same RG as gateway

echo "ExpressRoute Connection Setup"
echo "============================="

# Step 1: Verify ExpressRoute Gateway exists and is ready
echo "Step 1: Verifying ExpressRoute Gateway..."
GATEWAY_STATE=$(az network vnet-gateway show \
    --resource-group $RESOURCE_GROUP \
    --name $EXPRESSROUTE_GATEWAY_NAME \
    --query "provisioningState" \
    --output tsv 2>/dev/null)

if [ "$GATEWAY_STATE" != "Succeeded" ]; then
    echo "ERROR: Gateway $EXPRESSROUTE_GATEWAY_NAME is not ready. Current state: $GATEWAY_STATE"
    echo "Please wait for the gateway to be fully provisioned before creating the connection."
    exit 1
fi
echo "✓ Gateway $EXPRESSROUTE_GATEWAY_NAME is ready (State: $GATEWAY_STATE)"

# Step 2: Get ExpressRoute Circuit Resource ID
echo ""
echo "Step 2: Getting ExpressRoute Circuit details..."
CIRCUIT_ID=$(az network express-route show \
    --resource-group $CIRCUIT_RESOURCE_GROUP \
    --name $CIRCUIT_NAME \
    --query "id" \
    --output tsv 2>/dev/null)

if [ -z "$CIRCUIT_ID" ]; then
    echo "ERROR: Cannot find ExpressRoute circuit '$CIRCUIT_NAME' in resource group '$CIRCUIT_RESOURCE_GROUP'"
    echo "Please verify the circuit name and resource group are correct."
    exit 1
fi

echo "✓ Found ExpressRoute Circuit:"
echo "  Name: $CIRCUIT_NAME"
echo "  Resource Group: $CIRCUIT_RESOURCE_GROUP"
echo "  Resource ID: $CIRCUIT_ID"

# Step 3: Get Circuit Status
echo ""
echo "Step 3: Checking ExpressRoute Circuit status..."
CIRCUIT_STATUS=$(az network express-route show \
    --resource-group $CIRCUIT_RESOURCE_GROUP \
    --name $CIRCUIT_NAME \
    --query "{ServiceProviderProvisioningState:serviceProviderProvisioningState, CircuitProvisioningState:circuitProvisioningState}" \
    --output table)

echo "Circuit Status:"
echo "$CIRCUIT_STATUS"

# Step 4: Check if connection already exists
echo ""
echo "Step 4: Checking for existing connections..."
EXISTING_CONNECTION=$(az network vpn-connection show \
    --resource-group $RESOURCE_GROUP \
    --name $CONNECTION_NAME \
    --query "name" \
    --output tsv 2>/dev/null)

if [ -n "$EXISTING_CONNECTION" ]; then
    echo "WARNING: Connection '$CONNECTION_NAME' already exists."
    echo "Would you like to continue anyway? (y/N)"
    read -r CONTINUE
    if [[ ! $CONTINUE =~ ^[Yy]$ ]]; then
        echo "Aborting connection creation."
        exit 0
    fi
fi

# Step 5: Create ExpressRoute Connection
echo ""
echo "Step 5: Creating ExpressRoute connection..."
echo "This may take a few minutes..."

az network vpn-connection create \
    --name $CONNECTION_NAME \
    --resource-group $RESOURCE_GROUP \
    --vnet-gateway1 $EXPRESSROUTE_GATEWAY_NAME \
    --express-route-circuit2 "$CIRCUIT_ID" \
    --location "southafricanorth"

if [ $? -eq 0 ]; then
    echo "✓ ExpressRoute connection created successfully!"
else
    echo "❌ Failed to create ExpressRoute connection."
    exit 1
fi

# Step 6: Verify Connection Status
echo ""
echo "Step 6: Verifying connection status..."
sleep 10  # Wait a moment for the connection to initialize

CONNECTION_STATUS=$(az network vpn-connection show \
    --resource-group $RESOURCE_GROUP \
    --name $CONNECTION_NAME \
    --query "{Name:name, ConnectionStatus:connectionStatus, ProvisioningState:provisioningState, ConnectionType:connectionType}" \
    --output table)

echo "Connection Details:"
echo "$CONNECTION_STATUS"

# Step 7: Get connection details for troubleshooting
echo ""
echo "Step 7: Getting detailed connection information..."
az network vpn-connection show \
    --resource-group $RESOURCE_GROUP \
    --name $CONNECTION_NAME \
    --query "{
        Name: name,
        ResourceGroup: resourceGroup,
        ProvisioningState: provisioningState,
        ConnectionStatus: connectionStatus,
        ConnectionType: connectionType,
        EgressBytesTransferred: egressBytesTransferred,
        IngressBytesTransferred: ingressBytesTransferred
    }" \
    --output table

echo ""
echo "================================================"
echo "ExpressRoute Connection Summary"
echo "================================================"
echo "Gateway: $EXPRESSROUTE_GATEWAY_NAME (RG: $RESOURCE_GROUP)"
echo "Circuit: $CIRCUIT_NAME (RG: $CIRCUIT_RESOURCE_GROUP)"
echo "Connection: $CONNECTION_NAME (RG: $RESOURCE_GROUP)"
echo ""
echo "Next Steps:"
echo "1. Verify the connection status shows as 'Connected'"
echo "2. Test connectivity from your on-premises network"
echo "3. Configure routing as needed"
echo ""
echo "To monitor the connection:"
echo "az network vpn-connection show \\"
echo "    --resource-group $RESOURCE_GROUP \\"
echo "    --name $CONNECTION_NAME \\"
echo "    --query connectionStatus"
echo ""
echo "Connection setup complete!"