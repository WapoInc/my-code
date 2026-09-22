#!/bin/bash
# Usage: bash 3_PEERING-set.sh <resource group>

RgName=$1

az network vnet peering create \
  --name VNET-T-1-TO-VNET-User-1 \
  --resource-group $RgName \
  --vnet-name VNET-T-1 \
  --remote-vnet VNET-User-1 \
  --allow-forwarded-traffic \
  --allow-vnet-access \
  --allow-gateway-transit

az network vnet peering create \
  --name VNET-User-1-TO-VNET-T-1 \
  --resource-group $RgName \
  --vnet-name VNET-User-1 \
  --remote-vnet VNET-T-1 \
  --allow-forwarded-traffic \
  --allow-vnet-access \
  --use-remote-gateways

az network vnet peering create \
  --name VNET-T-1-TO-VNET-User-2 \
  --resource-group $RgName \
  --vnet-name VNET-T-1 \
  --remote-vnet VNET-User-2 \
  --allow-forwarded-traffic \
  --allow-vnet-access \
  --allow-gateway-transit


az network vnet peering create \
  --name VNET-User-2-TO-VNET-T-1 \
  --resource-group $RgName \
  --vnet-name VNET-User-2 \
  --remote-vnet VNET-T-1 \
  --allow-forwarded-traffic \
  --allow-vnet-access \
  --use-remote-gateways
