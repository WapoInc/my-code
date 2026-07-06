#!/bin/bash

# Add SSH allow rule to the South Africa North firewall policy
# Source: 10.111.0.0/24  →  Destination: 10.112.0.0/24  on TCP/22

RG="vwan-san-ne-azfw-with-diags-v1-rg"
FW_POLICY="azfw-policy-hub1-san"
FW_RCG="DefaultNetworkRuleCollectionGroup"

EXISTING=$(az network firewall policy rule-collection-group collection list \
    --resource-group "$RG" \
    --policy-name "$FW_POLICY" \
    --rule-collection-group-name "$FW_RCG" \
    --query "[?name=='AllowSSH'].name" -o tsv 2>/dev/null)

if [[ -n "$EXISTING" ]]; then
    echo "Collection 'AllowSSH' already exists in $FW_POLICY — skipping."
else
    az network firewall policy rule-collection-group collection add-filter-collection \
        --resource-group "$RG" \
        --policy-name "$FW_POLICY" \
        --rule-collection-group-name "$FW_RCG" \
        --name "AllowSSH" \
        --collection-priority 200 \
        --action Allow \
        --rule-type NetworkRule \
        --rule-name "Allow-SSH-Spoke1-to-Spoke2" \
        --ip-protocols TCP \
        --source-addresses "10.111.0.0/24" \
        --destination-addresses "10.112.0.0/24" \
        --destination-ports 22
    echo "SSH allow rule added to $FW_POLICY"
fi
