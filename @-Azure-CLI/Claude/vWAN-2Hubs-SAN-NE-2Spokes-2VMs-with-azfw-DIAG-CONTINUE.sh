#!/bin/bash

# =============================================================================
# vWAN-2Hubs-SAN-NE-2Spokes-2VMs-with-azfw-DIAG-CONTINUE.sh
# =============================================================================
# Continuation script – appends Azure Firewall diagnostic settings to an
# already-deployed environment from vWAN-2Hubs-SAN-NE-2Spokes-2VMs-with-azfw-final.sh
#
# Runs:
#   Step 13 : Create Log Analytics Workspace
#   Step 14 : Enable diagnostic settings on both Azure Firewalls
#             Categories (AzNWTraffic equivalent):
#               - AzureFirewallNetworkRule  (legacy table – every network rule hit)
#               - AZFWNetworkRule           (resource-specific table equivalent)
#               - AZFWFlowTrace            (per-flow detail)
#               - AZFWFatFlow              (high-throughput flow aggregation)
#               - AzureFirewallApplicationRule / AZFWApplicationRule
#               - AllMetrics               (throughput, SNAT, health)
#
# Usage: chmod +x vWAN-2Hubs-SAN-NE-2Spokes-2VMs-with-azfw-DIAG-CONTINUE.sh
#        ./vWAN-2Hubs-SAN-NE-2Spokes-2VMs-with-azfw-DIAG-CONTINUE.sh
# =============================================================================

# =============================================================================
# VARIABLES  (must match the deployed environment)
# =============================================================================

RG="vwan-san-ne-azfw-final2-rg"

HUB1_LOCATION="southafricanorth"

AZF1_NAME="azfw-hub1-san"
AZF2_NAME="azfw-hub2-ne"

LAW_NAME="law-azfw-diag"
DIAG_NAME1="azfw1-diag-settings"
DIAG_NAME2="azfw2-diag-settings"

# =============================================================================
# HELPER
# =============================================================================
check() {
    if [ $? -ne 0 ]; then
        echo "ERROR: $1 failed. Exiting."
        exit 1
    fi
}

# =============================================================================
# STEP 13 – Log Analytics Workspace
# =============================================================================
echo ""
echo "=== Step 13: Creating Log Analytics Workspace: $LAW_NAME ==="

az monitor log-analytics workspace create \
    --resource-group "$RG" \
    --workspace-name "$LAW_NAME" \
    --location "$HUB1_LOCATION" \
    --output none
check "Log Analytics Workspace create"

LAW_ID=$(az monitor log-analytics workspace show \
    --resource-group "$RG" \
    --workspace-name "$LAW_NAME" \
    --query id -o tsv)
check "Log Analytics Workspace ID lookup"

echo "  Log Analytics Workspace ready."
echo "  ID: $LAW_ID"

# =============================================================================
# STEP 14 – Diagnostic Settings on both Azure Firewalls
# =============================================================================
echo ""
echo "=== Step 14: Enabling Diagnostic Settings on Azure Firewalls ==="

AZF1_ID=$(az network firewall show \
    --resource-group "$RG" \
    --name "$AZF1_NAME" \
    --query id -o tsv)
check "Azure Firewall 1 ID lookup"

AZF2_ID=$(az network firewall show \
    --resource-group "$RG" \
    --name "$AZF2_NAME" \
    --query id -o tsv)
check "Azure Firewall 2 ID lookup"

echo "  Enabling diagnostics on $AZF1_NAME..."
az monitor diagnostic-settings create \
    --resource "$AZF1_ID" \
    --workspace "$LAW_ID" \
    --name "$DIAG_NAME1" \
    --logs '[{"category":"AzureFirewallNetworkRule","enabled":true},{"category":"AzureFirewallApplicationRule","enabled":true},{"category":"AZFWNetworkRule","enabled":true},{"category":"AZFWApplicationRule","enabled":true},{"category":"AZFWFlowTrace","enabled":true},{"category":"AZFWFatFlow","enabled":true}]' \
    --metrics '[{"category":"AllMetrics","enabled":true}]' \
    --output none
check "Firewall 1 diagnostic settings"
echo "  $AZF1_NAME diagnostics → enabled."

echo "  Enabling diagnostics on $AZF2_NAME..."
az monitor diagnostic-settings create \
    --resource "$AZF2_ID" \
    --workspace "$LAW_ID" \
    --name "$DIAG_NAME2" \
    --logs '[{"category":"AzureFirewallNetworkRule","enabled":true},{"category":"AzureFirewallApplicationRule","enabled":true},{"category":"AZFWNetworkRule","enabled":true},{"category":"AZFWApplicationRule","enabled":true},{"category":"AZFWFlowTrace","enabled":true},{"category":"AZFWFatFlow","enabled":true}]' \
    --metrics '[{"category":"AllMetrics","enabled":true}]' \
    --output none
check "Firewall 2 diagnostic settings"
echo "  $AZF2_NAME diagnostics → enabled."

# =============================================================================
# SUMMARY
# =============================================================================
echo ""
echo "==============================================================================="
echo " Firewall Diagnostics Enabled!"
echo "==============================================================================="
echo ""
echo " Resource Group         : $RG"
echo " Log Analytics Workspace: $LAW_NAME"
echo ""
echo " Firewall 1 : $AZF1_NAME  →  diag setting: $DIAG_NAME1"
echo " Firewall 2 : $AZF2_NAME  →  diag setting: $DIAG_NAME2"
echo ""
echo " Log categories enabled:"
echo "   AzureFirewallNetworkRule   (AzNWTraffic – legacy table)"
echo "   AZFWNetworkRule            (AzNWTraffic – resource-specific table)"
echo "   AZFWFlowTrace              (per-flow detail)"
echo "   AZFWFatFlow                (high-throughput flow aggregation)"
echo "   AzureFirewallApplicationRule"
echo "   AZFWApplicationRule"
echo "   AllMetrics"
echo ""
echo " NOTE: Allow 5-10 min for first logs to appear in Log Analytics."
echo ""
echo " KQL – ICMP traffic through firewalls (legacy table):"
echo '   AzureFirewallNetworkRule'
echo '   | where Protocol == "ICMP"'
echo '   | project TimeGenerated, SourceIp, DestinationIp, Action, msg_s'
echo '   | order by TimeGenerated desc'
echo ""
echo " KQL – ICMP traffic (resource-specific table):"
echo '   AZFWNetworkRule'
echo '   | where Protocol == "ICMP"'
echo '   | project TimeGenerated, SourceIp, DestinationIp, Action'
echo '   | order by TimeGenerated desc'
echo ""
echo " KQL – All traffic through both firewalls:"
echo '   AzureFirewallNetworkRule'
echo '   | summarize count() by SourceIp, DestinationIp, Protocol, Action'
echo '   | order by count_ desc'
echo "==============================================================================="
