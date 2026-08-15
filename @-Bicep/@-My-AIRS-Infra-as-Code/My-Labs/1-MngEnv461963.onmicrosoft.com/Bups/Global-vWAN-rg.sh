#!/usr/bin/env bash

set -euo pipefail

TENANT_ID="5cba78fe-cc40-479a-9ee1-255423641bc9"
SUBSCRIPTION_ID="0cfd0d2a-2b38-4c93-ba14-cf79185bc683"
RESOURCE_GROUP="SA-North-vWAN"
LOCATION="southafricanorth"

if ! command -v az >/dev/null 2>&1; then
  echo "[ERROR] Azure CLI is not installed or is not available in PATH." >&2
  exit 1
fi

if ! az account show >/dev/null 2>&1; then
  echo "[ERROR] Sign in first with: az login --tenant $TENANT_ID" >&2
  exit 1
fi

az account set --subscription "$SUBSCRIPTION_ID"

ACTIVE_TENANT_ID=$(az account show --query tenantId --output tsv)
if [[ "$ACTIVE_TENANT_ID" != "$TENANT_ID" ]]; then
  echo "[ERROR] Subscription is not in the expected tenant: $TENANT_ID" >&2
  exit 1
fi

if az group show --name "$RESOURCE_GROUP" >/dev/null 2>&1; then
  echo "[SKIP] Resource group '$RESOURCE_GROUP' already exists."
else
  echo "[RG] Creating resource group '$RESOURCE_GROUP' in '$LOCATION'..."
  az group create \
    --name "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --output none
  echo "[RG] Resource group created."
fi

az group show \
  --name "$RESOURCE_GROUP" \
  --query '{name:name, location:location, provisioningState:properties.provisioningState}' \
  --output table