#!/bin/bash

# VPN Connection Packet Capture
# Captures traffic on an S2S VPN connection and saves the .pcap to Azure Blob Storage.
# Usage: ./VPN-Data-Capture.sh

set -euo pipefail

# ── Variables ────────────────────────────────────────────────────────────────
VPN_CONN_NAME="S2S-Connection-to-ZA-East-vDC"
VPN_CONN_RG="za-east-vdc"
STGNAME="myhdstash"
STGRG="My-HD-Stash"
STGCONTAINERNAME="vpncaptures"
CAPTURE_DURATION=60   # seconds

# ── Filter ───────────────────────────────────────────────────────────────────
# Note: az network vpn-connection packet-capture start does not support --filter-data.
# Filtering is only available for gateway-level capture (az network vnet-gateway packet-capture).
# The connection-level capture always captures all traffic on the connection.

# ── Credentials & SAS token ──────────────────────────────────────────────────
# Cross-platform date: macOS uses -v, Linux uses -d
if date -v+1d > /dev/null 2>&1; then
  ENDTIME=$(date -u -v+1d +"%Y-%m-%dT%H:%M:%SZ")
else
  ENDTIME=$(date -u -d "+1 day" +"%Y-%m-%dT%H:%M:%SZ")
fi

echo -e "\033[1;33mFetching storage credentials...\033[0m"
STGKEY=$(az storage account keys list \
  --resource-group "$STGRG" \
  --account-name "$STGNAME" \
  --query "[0].value" -o tsv)

# Ensure the container exists
az storage container create \
  --account-name "$STGNAME" \
  --account-key "$STGKEY" \
  --name "$STGCONTAINERNAME" \
  --output none

SAS_TOKEN=$(az storage container generate-sas \
  --account-name "$STGNAME" \
  --account-key "$STGKEY" \
  --name "$STGCONTAINERNAME" \
  --permissions rwd \
  --expiry "$ENDTIME" \
  --https-only \
  -o tsv)

STGURL="https://${STGNAME}.blob.core.windows.net/${STGCONTAINERNAME}?${SAS_TOKEN}"

# ── Pre-flight: verify connection exists ──────────────────────────────────────
echo -e "\033[1;33mVerifying VPN connection: ${VPN_CONN_NAME} in ${VPN_CONN_RG}...\033[0m"
if ! az network vpn-connection show \
     --resource-group "$VPN_CONN_RG" \
     --name "$VPN_CONN_NAME" \
     --output none 2>/dev/null; then
  echo -e "\033[1;31mERROR: VPN connection '${VPN_CONN_NAME}' was not found in resource group '${VPN_CONN_RG}'.\033[0m"
  echo "  • Verify the connection name:   az network vpn-connection list --resource-group \"${VPN_CONN_RG}\" -o table"
  echo "  • Verify the resource group:    az group list -o table"
  exit 1
fi

# ── Start capture ─────────────────────────────────────────────────────────────
echo -e "\033[1;33mStarting packet capture on connection: ${VPN_CONN_NAME}\033[0m"
az network vpn-connection packet-capture start \
  --resource-group "$VPN_CONN_RG" \
  --name "$VPN_CONN_NAME"

echo -e "\033[1;33mCapture running for ${CAPTURE_DURATION} seconds...\033[0m"
sleep "$CAPTURE_DURATION"

# ── Stop capture ──────────────────────────────────────────────────────────────
echo -e "\033[1;31mStopping capture and saving to storage...\033[0m"
az network vpn-connection packet-capture stop \
  --resource-group "$VPN_CONN_RG" \
  --name "$VPN_CONN_NAME" \
  --sas-url "$STGURL"

echo -e "\033[1;32mDone. Capture saved to: https://${STGNAME}.blob.core.windows.net/${STGCONTAINERNAME}/\033[0m"
echo "Download the .pcap file and open with Wireshark."