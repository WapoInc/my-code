#!/bin/bash

# Usage:
# ./azure-vpngw-packet-capture.sh <VPNGWName> <VPNGWRG> <StgName> <StgRG> <StgContainerName>

set -e

VPNGWNAME="ZA-East-vDC-VPN-GW"
VPNGWRG="za-east-vdc"
STGNAME="myhdstash"
STGRG="My-HD-Stash"
STGCONTAINERNAME="vpngateway-capture"

if [[ -z "$VPNGWNAME" || -z "$VPNGWRG" || -z "$STGNAME" || -z "$STGRG" || -z "$STGCONTAINERNAME" ]]; then
    echo "Usage: $0 <VPNGWName> <VPNGWRG> <StgName> <StgRG> <StgContainerName>"
    exit 1
fi

# Filters
# FILTER1='{"TracingFlags": 11,"MaxPacketBufferSize": 120,"MaxFileSize": 500,"Filters": [{"CaptureSingleDirectionTrafficOnly": false}]}'
# FILTER2='{"TracingFlags": 11,"MaxPacketBufferSize": 120,"MaxFileSize": 500,"Filters":[{"SourceSubnets":["10.60.4.4/32","10.200.1.5/32"],"DestinationSubnets":["10.60.4.4/32","10.200.1.5/32"],"CaptureSingleDirectionTrafficOnly": false}]}'

STARTTIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
ENDTIME=$(date -u -v+1d +"%Y-%m-%dT%H:%M:%SZ")

# Get Storage Account key
STGKEY=$(az storage account keys list --resource-group "$STGRG" --account-name "$STGNAME" --query "[0].value" -o tsv)

# Get SAS Token for container
SAS_TOKEN=$(az storage container generate-sas \
  --account-name "$STGNAME" \
  --account-key "$STGKEY" \
  --name "$STGCONTAINERNAME" \
  --permissions rwd \
  --expiry "$ENDTIME" \
  --https-only \
  -o tsv)

STGURL="https://${STGNAME}.blob.core.windows.net/${STGCONTAINERNAME}?${SAS_TOKEN}"

echo -e "\033[1;33mPlease wait, starting VPN Gateway packet capture...\033[0m"
az network vnet-gateway packet-capture start \
  --resource-group "$VPNGWRG" \
  --name "$VPNGWNAME" \
  --filter-data "$FILTER1"

echo -e "\033[1;33mReproduce your issue, then press Enter to stop the capture...\033[0m"
read -r

echo -e "\033[1;31mPlease wait, stopping VPN Gateway packet capture...\033[0m"
az network vnet-gateway packet-capture stop \
  --resource-group "$VPNGWRG" \
  --name "$VPNGWNAME" \
  --sas-url "$STGURL"

echo -e "\033[1;33mRetrieve packet captures using Storage Explorer over:\033[0m"
echo "Storage account: $STGNAME"
echo "Blob container: $STGCONTAINERNAME"