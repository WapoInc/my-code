#!/bin/bash
# ============================================================
# Deploy SA-West-HUB-v2 - VNet + ER GW + ER Connection + VM
# South Africa West  |  v3 - Parallel Deployment
# ============================================================
# Resources:
#   - Resource Group : SA-West-Region
#   - VNet           : SA-West-vnet  (10.30.0.0/22)
#   - GatewaySubnet  : 10.30.0.0/27
#   - Subnet-1       : 10.30.1.0/24
#   - ER Gateway     : SA-West-ER-GW (Standard SKU)
#   - ER Connection  : ER-SA-West-Connection-to-SA-North-Region
#   - ER Circuit     : ER-LTSA-SA-West (in ER-LTSA-rg)
#   - Ubuntu VM      : ZAW-vm-01  (Subnet-1, Standard_B2s)
#
# Parallel execution plan:
#   Phase 1 : Resource Group                     (sequential)
#   Phase 2 : VNet  ||  Public IP                (parallel)
#   Phase 3 : GatewaySubnet                      (sequential)
#   Phase 4 : ER Gateway (background) + Subnet-1 (sequential after GwSubnet)
#   Phase 5 : VM NIC                             (after Subnet-1)
#   Phase 6 : Ubuntu VM                          (after NIC)
#   Phase 7 : Wait for ER Gateway                (blocks here until GW ready)
#   Phase 8 : ER Connection                      (immediately after GW ready)
# ============================================================

set -euo pipefail

# --- Variables -----------------------------------------------
SUBSCRIPTION_ID="0cfd0d2a-2b38-4c93-ba14-cf79185bc683"
RESOURCE_GROUP="SA-West-Region"
LOCATION="southafricawest"

VNET_NAME="SA-West-vnet"
VNET_PREFIX="10.30.0.0/22"

GATEWAY_SUBNET_PREFIX="10.30.0.0/27"
SUBNET1_NAME="Subnet-1"
SUBNET1_PREFIX="10.30.1.0/24"

GW_NAME="SA-West-ER-GW"
GW_PIP_NAME="SA-West-ER-GW-pip"
GW_SKU="Standard"
GW_TYPE="ExpressRoute"

CONN_NAME="ER-SA-West-Connection-to-SA-North-Region"
ROUTING_WEIGHT="0"

CIRCUIT_RG="ER-LTSA-rg"
CIRCUIT_NAME="ER-LTSA-SA-West"

VM_NAME="ZAW-vm-01"
VM_NIC_NAME="ZAW-vm-01-nic"
VM_SIZE="Standard_B2s"
VM_IMAGE="Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest"
VM_ADMIN_USER="rootadmin"
VM_ADMIN_PW="P@ssw0rd123!"
# -------------------------------------------------------------

# Helper: wait for a background job PID and exit on failure
wait_for() {
  local pid=$1 label=$2
  wait "$pid"
  local exit_code=$?
  if [[ $exit_code -ne 0 ]]; then
    echo "[ERROR] $label failed (exit $exit_code). Aborting." >&2
    exit $exit_code
  fi
}

# ============================================================
# Deployment functions (each self-contained for background use)
# ============================================================

deploy_resource_group() {
  if az group show --name "$RESOURCE_GROUP" &>/dev/null; then
    echo "[DETECTED] Resource Group '$RESOURCE_GROUP' found in Azure."
    echo "[SKIP]     Skipping creation."
  else
    echo "[RG]  Creating Resource Group: $RESOURCE_GROUP in $LOCATION..."
    az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output none
    echo "[RG]  Done."
  fi
}

deploy_vnet() {
  if az network vnet show --resource-group "$RESOURCE_GROUP" --name "$VNET_NAME" &>/dev/null; then
    echo "[DETECTED] VNet '$VNET_NAME' found in '$RESOURCE_GROUP'."
    echo "[SKIP]     Skipping creation."
  else
    echo "[VNET] Creating VNet: $VNET_NAME ($VNET_PREFIX)..."
    az network vnet create \
      --resource-group "$RESOURCE_GROUP" \
      --name "$VNET_NAME" \
      --location "$LOCATION" \
      --address-prefixes "$VNET_PREFIX" \
      --output none
    echo "[VNET] Done."
  fi
}

deploy_public_ip() {
  if az network public-ip show --resource-group "$RESOURCE_GROUP" --name "$GW_PIP_NAME" &>/dev/null; then
    echo "[DETECTED] Public IP '$GW_PIP_NAME' found in '$RESOURCE_GROUP'."
    echo "[SKIP]     Skipping creation."
  else
    echo "[PIP]  Creating Public IP: $GW_PIP_NAME..."
    az network public-ip create \
      --resource-group "$RESOURCE_GROUP" \
      --name "$GW_PIP_NAME" \
      --location "$LOCATION" \
      --sku "Standard" \
      --allocation-method "Static" \
      --output none
    echo "[PIP]  Done."
  fi
}

deploy_gateway_subnet() {
  if az network vnet subnet show --resource-group "$RESOURCE_GROUP" --vnet-name "$VNET_NAME" --name "GatewaySubnet" &>/dev/null; then
    echo "[DETECTED] GatewaySubnet found in VNet '$VNET_NAME'."
    echo "[SKIP]     Skipping creation."
  else
    echo "[GWSUB] Creating GatewaySubnet ($GATEWAY_SUBNET_PREFIX)..."
    az network vnet subnet create \
      --resource-group "$RESOURCE_GROUP" \
      --vnet-name "$VNET_NAME" \
      --name "GatewaySubnet" \
      --address-prefix "$GATEWAY_SUBNET_PREFIX" \
      --output none
    echo "[GWSUB] Done."
  fi
}

deploy_subnet1() {
  if az network vnet subnet show --resource-group "$RESOURCE_GROUP" --vnet-name "$VNET_NAME" --name "$SUBNET1_NAME" &>/dev/null; then
    echo "[DETECTED] Subnet '$SUBNET1_NAME' found in VNet '$VNET_NAME'."
    echo "[SKIP]     Skipping creation."
  else
    echo "[SUB1] Creating $SUBNET1_NAME ($SUBNET1_PREFIX)..."
    az network vnet subnet create \
      --resource-group "$RESOURCE_GROUP" \
      --vnet-name "$VNET_NAME" \
      --name "$SUBNET1_NAME" \
      --address-prefix "$SUBNET1_PREFIX" \
      --output none
    echo "[SUB1] Done."
  fi
}

deploy_er_gateway() {
  if az network vnet-gateway show --resource-group "$RESOURCE_GROUP" --name "$GW_NAME" &>/dev/null; then
    echo "[DETECTED] ExpressRoute Gateway '$GW_NAME' found in '$RESOURCE_GROUP'."
    echo "[SKIP]     Skipping creation."
  else
    echo "[GW]   Creating ExpressRoute Gateway: $GW_NAME (SKU: $GW_SKU)..."
    echo "[GW]   NOTE: Gateway deployment typically takes 20-45 minutes."
    az network vnet-gateway create \
      --resource-group "$RESOURCE_GROUP" \
      --name "$GW_NAME" \
      --location "$LOCATION" \
      --vnet "$VNET_NAME" \
      --gateway-type "$GW_TYPE" \
      --sku "$GW_SKU" \
      --public-ip-addresses "$GW_PIP_NAME" \
      --output none

    echo "[GW]   Waiting for gateway to reach Succeeded state..."
    az network vnet-gateway wait \
      --resource-group "$RESOURCE_GROUP" \
      --name "$GW_NAME" \
      --created
    echo "[GW]   Done."
  fi
}

deploy_vm_nic() {
  if az network nic show --resource-group "$RESOURCE_GROUP" --name "$VM_NIC_NAME" &>/dev/null; then
    echo "[DETECTED] NIC '$VM_NIC_NAME' found in '$RESOURCE_GROUP'."
    echo "[SKIP]     Skipping creation."
  else
    echo "[NIC]  Creating NIC: $VM_NIC_NAME in $SUBNET1_NAME..."
    az network nic create \
      --resource-group "$RESOURCE_GROUP" \
      --name "$VM_NIC_NAME" \
      --location "$LOCATION" \
      --vnet-name "$VNET_NAME" \
      --subnet "$SUBNET1_NAME" \
      --output none
    echo "[NIC]  Done."
  fi
}

deploy_er_connection() {
  if az network vpn-connection show --resource-group "$RESOURCE_GROUP" --name "$CONN_NAME" &>/dev/null; then
    echo "[DETECTED] ER Connection '$CONN_NAME' found in '$RESOURCE_GROUP'."
    echo "[SKIP]     Skipping creation."
    return
  fi

  echo "[CONN] Retrieving ER Circuit resource ID..."
  CIRCUIT_ID=$(az network express-route show \
    --resource-group "$CIRCUIT_RG" \
    --name "$CIRCUIT_NAME" \
    --query id --output tsv 2>&1) || {
    echo "[CONN] ERROR: Failed to find ER Circuit '$CIRCUIT_NAME' in '$CIRCUIT_RG'." >&2
    exit 1
  }
  [[ -z "$CIRCUIT_ID" ]] && { echo "[CONN] ERROR: Circuit ID is empty." >&2; exit 1; }
  echo "[CONN] Circuit ID: $CIRCUIT_ID"

  echo "[CONN] Checking ER Circuit provisioning state..."
  CIRCUIT_PROV=$(az network express-route show \
    --resource-group "$CIRCUIT_RG" \
    --name "$CIRCUIT_NAME" \
    --query serviceProviderProvisioningState --output tsv 2>/dev/null)
  echo "[CONN] Circuit serviceProviderProvisioningState: $CIRCUIT_PROV"
  if [[ "$CIRCUIT_PROV" != "Provisioned" ]]; then
    echo "[CONN] WARNING: Circuit is not in 'Provisioned' state (current: '$CIRCUIT_PROV')."
    echo "       The connection may fail until the service provider completes provisioning."
  fi

  echo "[CONN] Retrieving ER Gateway resource ID..."
  GW_ID=$(az network vnet-gateway show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$GW_NAME" \
    --query id --output tsv 2>&1) || {
    echo "[CONN] ERROR: Failed to find Gateway '$GW_NAME'." >&2
    exit 1
  }
  [[ -z "$GW_ID" ]] && { echo "[CONN] ERROR: Gateway ID is empty." >&2; exit 1; }
  echo "[CONN] Gateway ID: $GW_ID"

  echo "[CONN] Creating ExpressRoute Connection: $CONN_NAME (with retry, up to 3 attempts)..."
  CONN_MAX_ATTEMPTS=3
  CONN_ATTEMPT=1
  CONN_EXIT=1
  while [[ $CONN_ATTEMPT -le $CONN_MAX_ATTEMPTS ]]; do
    echo "[CONN] Attempt $CONN_ATTEMPT of $CONN_MAX_ATTEMPTS..."
    CONN_EXIT=0
    CONN_OUTPUT=$(az network vpn-connection create \
      --resource-group "$RESOURCE_GROUP" \
      --name "$CONN_NAME" \
      --vnet-gateway1 "$GW_ID" \
      --express-route-circuit2 "$CIRCUIT_ID" \
      --routing-weight "$ROUTING_WEIGHT" 2>&1) || CONN_EXIT=$?
    if [[ $CONN_EXIT -eq 0 ]]; then
      echo "[CONN] Connection created successfully on attempt $CONN_ATTEMPT."
      break
    fi
    if echo "$CONN_OUTPUT" | grep -q "GatewaySubnetAddressSpaceOverlap"; then
      echo ""
      echo "[CONN] ERROR: Address space conflict — VNet '$VNET_NAME' ($VNET_PREFIX) overlaps" >&2
      echo "       with a VNet already connected to circuit '$CIRCUIT_NAME'." >&2
      exit 1
    fi
    echo "[CONN] Attempt $CONN_ATTEMPT failed (exit $CONN_EXIT). Error: $CONN_OUTPUT"
    if [[ $CONN_ATTEMPT -lt $CONN_MAX_ATTEMPTS ]]; then
      RETRY_WAIT=$((CONN_ATTEMPT * 60))
      echo "[CONN] Retrying in ${RETRY_WAIT}s..."
      az network vpn-connection delete \
        --resource-group "$RESOURCE_GROUP" \
        --name "$CONN_NAME" --yes &>/dev/null || true
      sleep $RETRY_WAIT
    fi
    CONN_ATTEMPT=$((CONN_ATTEMPT + 1))
  done

  if [[ $CONN_EXIT -ne 0 ]]; then
    echo "[CONN] ERROR: All $CONN_MAX_ATTEMPTS attempts failed." >&2
    echo "       Last error: $CONN_OUTPUT" >&2
    exit 1
  fi

  echo "[CONN] Waiting for connection to provision (timeout: 15 min)..."
  CONN_TIMEOUT=900; CONN_INTERVAL=30; CONN_ELAPSED=0
  while true; do
    CONN_STATE=$(az network vpn-connection show \
      --resource-group "$RESOURCE_GROUP" \
      --name "$CONN_NAME" \
      --query provisioningState -o tsv 2>/dev/null)
    echo "[CONN] [$CONN_ELAPSED s] provisioningState: $CONN_STATE"
    if [[ "$CONN_STATE" == "Succeeded" ]]; then
      echo "[CONN] Connection provisioned successfully."
      break
    elif [[ "$CONN_STATE" == "Failed" ]]; then
      echo "[CONN] ERROR: Connection reached Failed state." >&2; exit 1
    elif [[ $CONN_ELAPSED -ge $CONN_TIMEOUT ]]; then
      echo "[CONN] WARNING: Timed out — still '$CONN_STATE'. Check portal for status."
      break
    fi
    sleep $CONN_INTERVAL
    CONN_ELAPSED=$((CONN_ELAPSED + CONN_INTERVAL))
  done
}

deploy_vm() {
  if az vm show --resource-group "$RESOURCE_GROUP" --name "$VM_NAME" &>/dev/null; then
    echo "[DETECTED] VM '$VM_NAME' found in '$RESOURCE_GROUP'."
    echo "[SKIP]     Skipping creation."
  else
    echo "[VM]   Creating Ubuntu 22.04 VM: $VM_NAME (size: $VM_SIZE)..."
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
      --output none
    echo "[VM]   Done."
  fi
}

# ============================================================
# MAIN - Phased parallel execution
# ============================================================

echo "==> Setting subscription: $SUBSCRIPTION_ID"
az account set --subscription "$SUBSCRIPTION_ID"

# --------------------------------------------------
echo ""
echo "==> PHASE 1: Resource Group (sequential)"
deploy_resource_group

# --------------------------------------------------
echo ""
echo "==> PHASE 2: VNet + Public IP (parallel)"
deploy_vnet &   PID_VNET=$!
deploy_public_ip &  PID_PIP=$!
wait_for $PID_VNET  "VNet"
wait_for $PID_PIP   "Public IP"

# --------------------------------------------------
echo ""
echo "==> PHASE 3: GatewaySubnet (sequential - must complete before ER GW starts)"
deploy_gateway_subnet

# --------------------------------------------------
echo ""
echo "==> PHASE 4: ER Gateway launched in BACKGROUND + Subnet-1 (sequential)"
echo "            (ER GW runs in background while remaining resources are built)"
deploy_er_gateway &
PID_GW=$!
deploy_subnet1

# --------------------------------------------------
echo ""
echo "==> PHASE 5: VM NIC (after Subnet-1, ER GW still running in background)"
deploy_vm_nic

# --------------------------------------------------
echo ""
echo "==> PHASE 6: Ubuntu VM (after NIC, ER GW still running in background)"
deploy_vm

# --------------------------------------------------
echo ""
echo "==> PHASE 7: Watching ER Gateway until Succeeded (polls every 30s, timeout 60 min)..."
GW_WATCH_TIMEOUT=3600
GW_WATCH_INTERVAL=30
GW_WATCH_ELAPSED=0
while true; do
  GW_STATE=$(az network vnet-gateway show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$GW_NAME" \
    --query provisioningState -o tsv 2>/dev/null || echo "Unknown")
  echo "[GW]   [$GW_WATCH_ELAPSED s] provisioningState: $GW_STATE"
  if [[ "$GW_STATE" == "Succeeded" ]]; then
    echo "[GW]   Gateway is ready — proceeding to ER Connection."
    break
  elif [[ "$GW_STATE" == "Failed" ]]; then
    echo "[GW]   ERROR: Gateway reached Failed state. Aborting." >&2
    exit 1
  elif [[ $GW_WATCH_ELAPSED -ge $GW_WATCH_TIMEOUT ]]; then
    echo "[GW]   WARNING: Watch timed out after ${GW_WATCH_TIMEOUT}s — state is '$GW_STATE'."
    echo "[GW]   Continuing — gateway may still provision in background."
    break
  fi
  sleep $GW_WATCH_INTERVAL
  GW_WATCH_ELAPSED=$((GW_WATCH_ELAPSED + GW_WATCH_INTERVAL))
done

# Ensure the background job also exited cleanly
wait_for $PID_GW "ER Gateway background job"

# --------------------------------------------------
echo ""
echo "==> PHASE 8: ER Connection (immediately after ER Gateway is ready)"
deploy_er_connection

# --------------------------------------------------
echo ""
echo "==> All resources deployed successfully."
echo ""
echo "    Verify ER connection:"
echo "    az network vpn-connection show -g $RESOURCE_GROUP -n $CONN_NAME --query connectionStatus -o tsv"
echo ""
echo "    Verify VM:"
echo "    az vm show -g $RESOURCE_GROUP -n $VM_NAME --query provisioningState -o tsv"
echo ""
echo "==> Done."
