#!/usr/bin/env bash

# Fixes asymmetric routing: avs-vm replies to on-prem must return via AzFW, not the VPN gateway directly.
set -euo pipefail

SUBSCRIPTION="${AZURE_SUBSCRIPTION:-ME-MngEnvMCAP158201-viresent-1}"
RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-metro-bus-rg}"
ROUTE_TABLE="avs-to-on-prem"

if ! az account show >/dev/null 2>&1; then
  echo "Sign in to Azure before running this script: az login" >&2
  exit 1
fi

az account set --subscription "$SUBSCRIPTION"

FIREWALL_IP="$(az network firewall show \
  --resource-group "$RESOURCE_GROUP" \
  --name "AzFW" \
  --query "ipConfigurations[0].privateIPAddress" \
  --output tsv 2>/dev/null)"

echo "Resource group: $RESOURCE_GROUP"
echo "Azure Firewall private IP: $FIREWALL_IP"

az network route-table create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$ROUTE_TABLE" \
  --output none

az network route-table route create \
  --resource-group "$RESOURCE_GROUP" \
  --route-table-name "$ROUTE_TABLE" \
  --name "avs-to-on-prem" \
  --address-prefix "192.168.0.0/22" \
  --next-hop-type VirtualAppliance \
  --next-hop-ip-address "$FIREWALL_IP" \
  --output none

az network route-table route create \
  --resource-group "$RESOURCE_GROUP" \
  --route-table-name "$ROUTE_TABLE" \
  --name "avs-to-on-prem-4" \
  --address-prefix "192.168.4.0/22" \
  --next-hop-type VirtualAppliance \
  --next-hop-ip-address "$FIREWALL_IP" \
  --output none

az network vnet subnet update \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "avs-vnet" \
  --name "avs-subnet" \
  --route-table "$ROUTE_TABLE" \
  --output none

echo
echo "Routes in $ROUTE_TABLE:"
az network route-table route list \
  --resource-group "$RESOURCE_GROUP" \
  --route-table-name "$ROUTE_TABLE" \
  --query "[].{Name:name, Prefix:addressPrefix, NextHop:nextHopIpAddress}" \
  --output table

echo
echo "avs-vm effective routes to on-premises (expect User -> $FIREWALL_IP):"
az network nic show-effective-route-table \
  --resource-group "$RESOURCE_GROUP" \
  --name "avs-vm-nic" \
  --query "value[?starts_with(addressPrefix[0], '192.168.')].{Source:source, State:state, Prefix:join(', ', addressPrefix), NextHopType:nextHopType, NextHop:join(', ', nextHopIpAddress)}" \
  --output table

echo
echo "Test from onprem-vm1: ssh adminazure@172.16.1.4"
