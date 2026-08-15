#!/bin/bash
# ============================================================
# Deploy ZAW VNet + ExpressRoute Gateway + ER Connection v2
# South Africa West
# ============================================================
# Resources:
#   - Resource Group : SA-West-HUB
#   - VNet           : SA-West-vnet  (10.30.0.0/22)
#   - GatewaySubnet  : 10.30.0.0/27
#   - Subnet-1       : 10.30.1.0/24
#   - ER Gateway     : ZAW-er-gw (Standard SKU)
#   - ER Connection  : ER-SA-West-Connection-to-SA-North-Region
#   - ER Circuit     : ER-LTSA-SA-West (in ER-LTSA-rg)
#   - Ubuntu VM      : ZAW-vm-01  (Subnet-1, Standard_B2s)
# ============================================================

set -e

# --- Variables -----------------------------------------------
SUBSCRIPTION_ID="0cfd0d2a-2b38-4c93-ba14-cf79185bc683"
RESOURCE_GROUP="SA-West-HUB"
LOCATION="southafricawest"

VNET_NAME="SA-West-vnet"
VNET_PREFIX="10.30.0.0/22"

GATEWAY_SUBNET_PREFIX="10.30.0.0/27"
SUBNET1_NAME="Subnet-1"
SUBNET1_PREFIX="10.30.1.0/24"

GW_NAME="ZAW-er-gw"
GW_PIP_NAME="ZAW-er-gw-pip"
GW_SKU="Standard"
GW_TYPE="ExpressRoute"

# ER Connection
CONN_NAME="ER-SA-West-Connection-to-SA-North-Region"
CONN_TYPE="ExpressRoute"
ROUTING_WEIGHT="0"

# ER Circuit (source) - located in ER-LTSA-rg
CIRCUIT_RG="ER-LTSA-rg"
CIRCUIT_NAME="ER-LTSA-SA-West"

# Ubuntu VM  (Standard_B2s = 2 vCPU / 4 GB — closest to 2 vCPU/2 GB in Azure)
VM_NAME="ZAW-vm-01"
VM_NIC_NAME="ZAW-vm-01-nic"
VM_SIZE="Standard_B2s"
VM_IMAGE="Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest"
VM_ADMIN_USER="rootadmin"
VM_ADMIN_PW="P@ssw0rd123!"
# -------------------------------------------------------------

echo "==> Setting subscription..."
az account set --subscription "$SUBSCRIPTION_ID"

# --- Resource Group ------------------------------------------
if az group show --name "$RESOURCE_GROUP" &>/dev/null; then
  echo "[DETECTED] Resource Group '$RESOURCE_GROUP' found in Azure."
  echo "[SKIP]     Skipping creation."
else
  echo "==> Creating Resource Group: $RESOURCE_GROUP in $LOCATION..."
  az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
fi

# --- VNet ----------------------------------------------------
if az network vnet show --resource-group "$RESOURCE_GROUP" --name "$VNET_NAME" &>/dev/null; then
  echo "[DETECTED] VNet '$VNET_NAME' found in '$RESOURCE_GROUP'."
  echo "[SKIP]     Skipping creation."
else
  echo "==> Creating VNet: $VNET_NAME ($VNET_PREFIX)..."
  az network vnet create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VNET_NAME" \
    --location "$LOCATION" \
    --address-prefixes "$VNET_PREFIX"
fi

# --- GatewaySubnet -------------------------------------------
if az network vnet subnet show --resource-group "$RESOURCE_GROUP" --vnet-name "$VNET_NAME" --name "GatewaySubnet" &>/dev/null; then
  echo "[DETECTED] GatewaySubnet found in VNet '$VNET_NAME'."
  echo "[SKIP]     Skipping creation."
else
  echo "==> Creating GatewaySubnet ($GATEWAY_SUBNET_PREFIX)..."
  az network vnet subnet create \
    --resource-group "$RESOURCE_GROUP" \
    --vnet-name "$VNET_NAME" \
    --name "GatewaySubnet" \
    --address-prefix "$GATEWAY_SUBNET_PREFIX"
fi

# --- Subnet-1 ------------------------------------------------
if az network vnet subnet show --resource-group "$RESOURCE_GROUP" --vnet-name "$VNET_NAME" --name "$SUBNET1_NAME" &>/dev/null; then
  echo "[DETECTED] Subnet '$SUBNET1_NAME' found in VNet '$VNET_NAME'."
  echo "[SKIP]     Skipping creation."
else
  echo "==> Creating $SUBNET1_NAME ($SUBNET1_PREFIX)..."
  az network vnet subnet create \
    --resource-group "$RESOURCE_GROUP" \
    --vnet-name "$VNET_NAME" \
    --name "$SUBNET1_NAME" \
    --address-prefix "$SUBNET1_PREFIX"
fi

# --- Public IP -----------------------------------------------
if az network public-ip show --resource-group "$RESOURCE_GROUP" --name "$GW_PIP_NAME" &>/dev/null; then
  echo "[DETECTED] Public IP '$GW_PIP_NAME' found in '$RESOURCE_GROUP'."
  echo "[SKIP]     Skipping creation."
else
  echo "==> Creating Public IP: $GW_PIP_NAME..."
  az network public-ip create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$GW_PIP_NAME" \
    --location "$LOCATION" \
    --sku "Standard" \
    --allocation-method "Static"
fi

# --- ER Gateway ----------------------------------------------
if az network vnet-gateway show --resource-group "$RESOURCE_GROUP" --name "$GW_NAME" &>/dev/null; then
  echo "[DETECTED] ExpressRoute Gateway '$GW_NAME' found in '$RESOURCE_GROUP'."
  echo "[SKIP]     Skipping creation."
else
  echo "==> Creating ExpressRoute Gateway: $GW_NAME (SKU: $GW_SKU)..."
  echo "    NOTE: Gateway deployment typically takes 20-45 minutes."
  az network vnet-gateway create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$GW_NAME" \
    --location "$LOCATION" \
    --vnet "$VNET_NAME" \
    --gateway-type "$GW_TYPE" \
    --sku "$GW_SKU" \
    --public-ip-addresses "$GW_PIP_NAME"

  echo "==> Waiting for gateway to reach Succeeded state..."
  az network vnet-gateway wait \
    --resource-group "$RESOURCE_GROUP" \
    --name "$GW_NAME" \
    --created
fi

# --- ER Connection -------------------------------------------
if az network vpn-connection show --resource-group "$RESOURCE_GROUP" --name "$CONN_NAME" &>/dev/null; then
  echo "[DETECTED] ER Connection '$CONN_NAME' found in '$RESOURCE_GROUP'."
  echo "[SKIP]     Skipping creation."
else
  echo "==> Retrieving ER Circuit resource ID..."
  CIRCUIT_ID=$(az network express-route show \
    --resource-group "$CIRCUIT_RG" \
    --name "$CIRCUIT_NAME" \
    --query id \
    --output tsv 2>&1) || {
    echo "ERROR: Failed to find ER Circuit '$CIRCUIT_NAME' in resource group '$CIRCUIT_RG'."
    echo "       Verify the circuit name and resource group are correct and you have access."
    exit 1
  }
  if [[ -z "$CIRCUIT_ID" ]]; then
    echo "ERROR: Circuit ID returned empty. Check CIRCUIT_RG='$CIRCUIT_RG' and CIRCUIT_NAME='$CIRCUIT_NAME'."
    exit 1
  fi
  echo "    Circuit ID: $CIRCUIT_ID"

  echo "==> Retrieving ER Gateway resource ID..."
  GW_ID=$(az network vnet-gateway show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$GW_NAME" \
    --query id \
    --output tsv 2>&1) || {
    echo "ERROR: Failed to find Gateway '$GW_NAME' in resource group '$RESOURCE_GROUP'."
    exit 1
  }
  if [[ -z "$GW_ID" ]]; then
    echo "ERROR: Gateway ID returned empty. Check RESOURCE_GROUP='$RESOURCE_GROUP' and GW_NAME='$GW_NAME'."
    exit 1
  fi
  echo "    Gateway ID: $GW_ID"

  echo "==> Creating ExpressRoute Connection: $CONN_NAME..."
  CONN_OUTPUT=$(az network vpn-connection create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$CONN_NAME" \
    --vnet-gateway1 "$GW_ID" \
    --express-route-circuit2 "$CIRCUIT_ID" \
    --routing-weight "$ROUTING_WEIGHT" 2>&1) || {
    if echo "$CONN_OUTPUT" | grep -q "GatewaySubnetAddressSpaceOverlap"; then
      echo ""
      echo "ERROR: Address space conflict detected."
      echo "       VNet '$VNET_NAME' ($VNET_PREFIX) overlaps with a VNet already"
      echo "       connected to circuit '$CIRCUIT_NAME'."
      echo ""
      echo "       Resolution: Change the VNet address space to a non-overlapping range,"
      echo "       or check existing circuit connections with:"
      echo "       az network express-route show -g $CIRCUIT_RG -n $CIRCUIT_NAME --query 'peerings' -o table"
    else
      echo "ERROR: Connection creation failed:"
      echo "$CONN_OUTPUT"
    fi
    exit 1
  }

  echo "==> Waiting for connection to provision (timeout: 15 min)..."
  CONN_TIMEOUT=900   # 15 minutes
  CONN_INTERVAL=30
  CONN_ELAPSED=0
  while true; do
    CONN_STATE=$(az network vpn-connection show \
      --resource-group "$RESOURCE_GROUP" \
      --name "$CONN_NAME" \
      --query provisioningState -o tsv 2>/dev/null)
    echo "    [$CONN_ELAPSED s] provisioningState: $CONN_STATE"
    if [[ "$CONN_STATE" == "Succeeded" ]]; then
      echo "==> Connection provisioned successfully."
      break
    elif [[ "$CONN_STATE" == "Failed" ]]; then
      echo "ERROR: Connection reached Failed state. Check the Azure portal for details."
      exit 1
    elif [[ $CONN_ELAPSED -ge $CONN_TIMEOUT ]]; then
      echo "WARNING: Timed out after ${CONN_TIMEOUT}s — connection is still '$CONN_STATE'."
      echo "         The connection may still provision in the background. Check with:"
      echo "         az network vpn-connection show -g $RESOURCE_GROUP -n $CONN_NAME --query provisioningState -o tsv"
      break
    fi
    sleep $CONN_INTERVAL
    CONN_ELAPSED=$((CONN_ELAPSED + CONN_INTERVAL))
  done
fi

# --- Ubuntu 22.04 VM -----------------------------------------
if az vm show --resource-group "$RESOURCE_GROUP" --name "$VM_NAME" &>/dev/null; then
  echo "[DETECTED] VM '$VM_NAME' found in '$RESOURCE_GROUP'."
  echo "[SKIP]     Skipping creation."
else
  echo "==> Creating NIC: $VM_NIC_NAME in $SUBNET1_NAME..."
  az network nic create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VM_NIC_NAME" \
    --location "$LOCATION" \
    --vnet-name "$VNET_NAME" \
    --subnet "$SUBNET1_NAME"

  echo "==> Creating Ubuntu 22.04 VM: $VM_NAME (size: $VM_SIZE)..."
  az vm create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VM_NAME" \
    --location "$LOCATION" \
    --nics "$VM_NIC_NAME" \
    --image "$VM_IMAGE" \
    --size "$VM_SIZE" \
    --admin-username "$VM_ADMIN_USER" \
    --admin-password "$VM_ADMIN_PW" \
    --authentication-type password \
    --no-wait

  echo "==> VM deployment initiated (--no-wait). Monitor with:"
  echo "    az vm show -g $RESOURCE_GROUP -n $VM_NAME --query provisioningState -o tsv"
fi

echo ""
echo "==> Deployment complete. Verify connection with:"
echo "    az network vpn-connection show -g $RESOURCE_GROUP -n $CONN_NAME --query connectionStatus -o tsv"
echo ""
echo "==> Done."
