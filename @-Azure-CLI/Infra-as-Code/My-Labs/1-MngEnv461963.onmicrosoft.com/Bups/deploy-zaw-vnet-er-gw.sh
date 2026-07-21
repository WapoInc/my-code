#!/bin/bash
# ============================================================
# Deploy ZAW VNet + ExpressRoute Gateway - South Africa West
# ============================================================
# Resources:
#   - Resource Group : SA-West-rg-test
#   - VNet           : ZAW-vnet  (10.30.0.0/22)
#   - GatewaySubnet  : 10.30.0.0/27
#   - Subnet-1       : 10.30.1.0/24
#   - ER Gateway     : ZAW-er-gw (Standard SKU)
# ============================================================

set -e

# --- Variables -----------------------------------------------
SUBSCRIPTION_ID="0cfd0d2a-2b38-4c93-ba14-cf79185bc683"
RESOURCE_GROUP="SA-West-rg-test"
LOCATION="southafricawest"

VNET_NAME="ZAW-vnet"
VNET_PREFIX="10.30.0.0/22"

GATEWAY_SUBNET_PREFIX="10.30.0.0/27"
SUBNET1_NAME="Subnet-1"
SUBNET1_PREFIX="10.30.1.0/24"

GW_NAME="ZAW-er-gw"
GW_PIP_NAME="ZAW-er-gw-pip"
GW_SKU="Standard"
GW_TYPE="ExpressRoute"
# -------------------------------------------------------------

echo "==> Setting subscription..."
az account set --subscription "$SUBSCRIPTION_ID"

echo "==> Creating Resource Group: $RESOURCE_GROUP in $LOCATION..."
az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION"

echo "==> Creating VNet: $VNET_NAME ($VNET_PREFIX)..."
az network vnet create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VNET_NAME" \
  --location "$LOCATION" \
  --address-prefixes "$VNET_PREFIX"

echo "==> Creating GatewaySubnet ($GATEWAY_SUBNET_PREFIX)..."
az network vnet subnet create \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --name "GatewaySubnet" \
  --address-prefix "$GATEWAY_SUBNET_PREFIX"

echo "==> Creating Subnet-1 ($SUBNET1_PREFIX)..."
az network vnet subnet create \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --name "$SUBNET1_NAME" \
  --address-prefix "$SUBNET1_PREFIX"

echo "==> Creating Public IP for ER Gateway: $GW_PIP_NAME..."
az network public-ip create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$GW_PIP_NAME" \
  --location "$LOCATION" \
  --sku "Standard" \
  --allocation-method "Static"

echo "==> Creating ExpressRoute Gateway: $GW_NAME (SKU: $GW_SKU)..."
echo "    NOTE: Gateway deployment typically takes 20-45 minutes."
az network vnet-gateway create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$GW_NAME" \
  --location "$LOCATION" \
  --vnet "$VNET_NAME" \
  --gateway-type "$GW_TYPE" \
  --sku "$GW_SKU" \
  --public-ip-addresses "$GW_PIP_NAME" \
  --no-wait

echo ""
echo "==> Gateway deployment initiated (--no-wait). Monitor with:"
echo "    az network vnet-gateway show -g $RESOURCE_GROUP -n $GW_NAME --query provisioningState -o tsv"
echo ""
echo "==> Done."
