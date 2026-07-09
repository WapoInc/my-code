#!/usr/bin/env bash
set -euo pipefail

# ========= Config =========
SUBSCRIPTION_ID="ME-MngEnvMCAP056429-Connectivity"
LOCATION="southafricanorth"

RG_NAME="github-copilot-3"
VNET_NAME="github-copilot-3-vnet"
VNET_PREFIX="172.16.100.0/24"
SUBNET_NAME="default"
SUBNET_PREFIX="172.16.100.0/25"

VM_NAME="github-copilot-3-vm"
VM_SIZE="Standard_B2s"
IMAGE="Ubuntu2204"
ADMIN_USERNAME="rootadmin"
ADMIN_PASSWORD='P@ssw0rd123!'

# ========= Azure infra =========
az account set --subscription "$SUBSCRIPTION_ID"

az group create \
  --name "$RG_NAME" \
  --location "$LOCATION"

az network vnet create \
  --resource-group "$RG_NAME" \
  --name "$VNET_NAME" \
  --location "$LOCATION" \
  --address-prefixes "$VNET_PREFIX" \
  --subnet-name "$SUBNET_NAME" \
  --subnet-prefixes "$SUBNET_PREFIX"

az vm create \
  --resource-group "$RG_NAME" \
  --name "$VM_NAME" \
  --location "$LOCATION" \
  --image "$IMAGE" \
  --size "$VM_SIZE" \
  --admin-username "$ADMIN_USERNAME" \
  --admin-password "$ADMIN_PASSWORD" \
  --authentication-type password \
  --vnet-name "$VNET_NAME" \
  --subnet "$SUBNET_NAME" \
  --public-ip-sku Standard

# Allow HTTP from Internet
az vm open-port \
  --resource-group "$RG_NAME" \
  --name "$VM_NAME" \
  --port 80 \
  --priority 1010

# ========= Configure VM (install/start Apache + Hello World) =========
az vm run-command invoke \
  --resource-group "$RG_NAME" \
  --name "$VM_NAME" \
  --command-id RunShellScript \
  --scripts '
set -e
sudo apt-get update -y
sudo apt-get install -y apache2
sudo systemctl enable --now apache2
echo "<!doctype html><html><body><h1>Hello World-Ubuntu-3</h1></body></html>" | sudo tee /var/www/html/index.html >/dev/null
sudo ss -tulpen | grep ":80" || true
'

PUBLIC_IP=$(az vm list-ip-addresses \
  --resource-group "$RG_NAME" \
  --name "$VM_NAME" \
  --query "[0].virtualMachine.network.publicIpAddresses[0].ipAddress" \
  -o tsv)

echo "Done. Browse: http://$PUBLIC_IP"
