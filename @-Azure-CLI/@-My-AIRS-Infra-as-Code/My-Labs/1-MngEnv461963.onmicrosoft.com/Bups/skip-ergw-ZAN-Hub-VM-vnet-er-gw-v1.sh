#!/bin/bash
# ============================================================
# Deploy SA-North-HUB - VNet + VM  (ER Gateway SKIPPED)
# South Africa North  |  v5 - Parallel Deployment
# ============================================================
# This variant deploys the same hub network and VM but SKIPS
# creation of the ExpressRoute Gateway (and its public IP).
#
# Resources:
#   - Resource Group    : SA-North-region
#   - VNet              : SA-North-vnet  (10.10.0.0/16)
#   - GatewaySubnet     : 10.10.0.0/24
#   - SubNet-1          : 10.10.1.0/24
#   - ER Gateway        : SKIPPED
#   - Ubuntu VM         : ZAN-JB-1  (SubNet-1, Standard_B2s, private IP 10.10.1.5, no public IP)
#
# Execution plan:
#   Phase 1 : Resource Group   (sequential)
#   Phase 2 : VNet             (sequential)
#   Phase 3 : Subnets          (sequential after VNet)
#   Phase 4 : VM NIC           (after SubNet-1)
#   Phase 5 : Ubuntu VM        (after NIC)
# =============================================================================

set -euo pipefail

# --- Variables -----------------------------------------------
TENANT_ID="5cba78fe-cc40-479a-9ee1-255423641bc9"
SUBSCRIPTION_ID="0cfd0d2a-2b38-4c93-ba14-cf79185bc683"
RESOURCE_GROUP="SA-North-region"
LOCATION="southafricanorth"

VNET_NAME="SA-North-vnet"
VNET_PREFIX="10.10.0.0/16"

GATEWAY_SUBNET_PREFIX="10.10.0.0/24"
SUBNET1_NAME="SubNet-1"
SUBNET1_PREFIX="10.10.1.0/24"

VM_NAME="ZAN-JB-1"
VM_NIC_NAME="ZAN-JB-1-nic"
VM_SIZE="Standard_B2s"
VM_IMAGE="Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest"
VM_PRIVATE_IP="10.10.1.5"
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

deploy_vm_nic() {
  echo "[NIC]  Creating NIC: $VM_NIC_NAME in $SUBNET1_NAME (static private IP $VM_PRIVATE_IP, no public IP)..."
  az network nic create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VM_NIC_NAME" \
    --location "$LOCATION" \
    --vnet-name "$VNET_NAME" \
    --subnet "$SUBNET1_NAME" \
    --private-ip-address "$VM_PRIVATE_IP" \
    --output none
  echo "[NIC]  Done."
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
# MAIN - Phased execution (ER Gateway skipped)
# ============================================================

echo "==> Ensuring sign-in to tenant $TENANT_ID / subscription $SUBSCRIPTION_ID..."
CURRENT_TENANT=$(az account show --query tenantId -o tsv 2>/dev/null || echo "")
CURRENT_SUB=$(az account show --query id -o tsv 2>/dev/null || echo "")

if [[ "$CURRENT_TENANT" != "$TENANT_ID" || "$CURRENT_SUB" != "$SUBSCRIPTION_ID" ]]; then
  echo "==> Not signed in to the required tenant/subscription. Logging in..."
  az logout &>/dev/null || true
  az login \
    --tenant "$TENANT_ID" \
    --scope "https://management.core.windows.net//.default" \
    --output none
fi

echo "==> Setting subscription: $SUBSCRIPTION_ID"
az account set --subscription "$SUBSCRIPTION_ID"

# Confirm we landed on the correct tenant + subscription before doing any work
ACTIVE_TENANT=$(az account show --query tenantId -o tsv)
ACTIVE_SUB=$(az account show --query id -o tsv)
if [[ "$ACTIVE_TENANT" != "$TENANT_ID" || "$ACTIVE_SUB" != "$SUBSCRIPTION_ID" ]]; then
  echo "[ERROR] Active context (tenant $ACTIVE_TENANT / sub $ACTIVE_SUB) does not match" >&2
  echo "        required tenant $TENANT_ID / sub $SUBSCRIPTION_ID. Aborting." >&2
  exit 1
fi
echo "==> Confirmed: tenant $ACTIVE_TENANT / subscription $ACTIVE_SUB"

# --------------------------------------------------
echo ""
echo "==> PHASE 1: Resource Group (sequential)"
deploy_resource_group

# --------------------------------------------------
echo ""
echo "==> PHASE 2: VNet (sequential)"
deploy_vnet

# --------------------------------------------------
echo ""
echo "==> PHASE 3: Subnets (sequential after VNet)"
deploy_gateway_subnet
deploy_subnet1

# --------------------------------------------------
echo ""
echo "==> PHASE 4: VM NIC (after Subnet-1)"
deploy_vm_nic

# --------------------------------------------------
echo ""
echo "==> PHASE 5: Ubuntu VM (after NIC)"
deploy_vm

# --------------------------------------------------
echo ""
echo "==> All resources deployed successfully (ER Gateway skipped)."
echo ""
echo "    Verify VM:"
echo "    az vm show -g $RESOURCE_GROUP -n $VM_NAME --query provisioningState -o tsv"
echo ""
echo "==> Done."
