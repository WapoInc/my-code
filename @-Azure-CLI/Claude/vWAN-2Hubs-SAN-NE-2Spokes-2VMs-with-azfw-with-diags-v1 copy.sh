#!/bin/bash

# =============================================================================
# vWAN-2Hubs-SAN-NE-2Spokes-2VMs-with-azfw-final.sh
# =============================================================================
# FINAL validated script – merged from all successful run segments.
#
# Fixes applied vs original:
#   1. --ip-protocols ICMP  (not --protocols) for network firewall policy rules
#   2. next-hop shorthand   (not nexthop JSON) for vhub routing-intent create
#   3. --vhub               (not --vhub-name)  for vhub routing-intent create
#
# Creates:
#   - Virtual WAN (Standard)
#   - Hub 1 : South Africa North  (192.168.111.0/24) – secured with Azure Firewall
#   - Hub 2 : Northern Europe     (192.168.112.0/24) – secured with Azure Firewall
#   - Spoke VNet per hub, connected to its hub
#   - 1 Ubuntu 22.04 VM per spoke (public IP enabled)
#   - NSG per spoke: SSH restricted to caller IP + ICMP allowed from other spoke
#   - Azure Firewall Policy per hub (Standard) with ICMP allow rule (cross-spoke ping)
#   - Azure Firewall (Standard) deployed inside each hub
#   - Routing Intent (PrivateTraffic → Azure Firewall) on each hub
#
# Pre-requisite: Azure CLI with virtual-wan and azure-firewall extensions
#   az extension add --name virtual-wan
#   az extension add --name azure-firewall
#
# Usage: chmod +x vWAN-2Hubs-SAN-NE-2Spokes-2VMs-with-azfw-final.sh
#        ./vWAN-2Hubs-SAN-NE-2Spokes-2VMs-with-azfw-final.sh
#
# NOTE: Azure Firewall in a secured hub takes ~20-30 min each to provision.
#       Total runtime is approximately 60-90 minutes.
# =============================================================================

# =============================================================================
# VARIABLES
# =============================================================================

RG="vwan-san-ne-azfw-with-diags-v1-rg"
VWAN="vwan-san-ne-azfw"

# Hub 1 – South Africa North
HUB1_NAME="hub-southafricanorth"
HUB1_LOCATION="southafricanorth"
HUB1_CIDR="192.168.111.0/24"

# Hub 2 – Northern Europe
HUB2_NAME="hub-northerneurope"
HUB2_LOCATION="northeurope"
HUB2_CIDR="192.168.112.0/24"

# Spoke 1 (attached to Hub 1)
SPOKE1_VNET="spoke1-san-vnet"
SPOKE1_CIDR="10.111.0.0/24"
SPOKE1_SUBNET="spoke1-subnet"
SPOKE1_SUBNET_CIDR="10.111.0.0/25"
SPOKE1_CONN="spoke1-to-hub1"

# Spoke 2 (attached to Hub 2)
SPOKE2_VNET="spoke2-ne-vnet"
SPOKE2_CIDR="10.112.0.0/24"
SPOKE2_SUBNET="spoke2-subnet"
SPOKE2_SUBNET_CIDR="10.112.0.0/25"
SPOKE2_CONN="spoke2-to-hub2"

# VM Configuration
VM_SIZE="Standard_B2s"
ADMIN_USERNAME="rootadmin"
ADMIN_PASSWORD="P@ssw0rd123!"
IMAGE="Ubuntu2204"
VM1_NAME="vm-spoke1-san"
VM2_NAME="vm-spoke2-ne"

# NSG names
NSG1="nsg-spoke1-san"
NSG2="nsg-spoke2-ne"

# Azure Firewall names
AZF1_NAME="azfw-hub1-san"
AZF2_NAME="azfw-hub2-ne"

# Azure Firewall Policy names
FW_POLICY1_NAME="azfw-policy-hub1-san"
FW_POLICY2_NAME="azfw-policy-hub2-ne"

# Rule Collection Group (shared name used in both policies)
FW_RCG_NAME="DefaultNetworkRuleCollectionGroup"

# Log Analytics Workspaces (one per firewall – Resource Specific diagnostics)
LAW1_NAME="law-azfw-hub1-san"
LAW2_NAME="law-azfw-hub2-ne"
DIAG_NAME1="azfw1-diag-settings"
DIAG_NAME2="azfw2-diag-settings"

# Caller's public IP — restricts SSH access in NSG
MY_IP=$(curl -4 -s ifconfig.io)
echo "Detected public IP for SSH NSG rule: $MY_IP"

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================
check() {
    if [ $? -ne 0 ]; then
        echo "ERROR: $1 failed. Exiting."
        exit 1
    fi
}

# Poll Azure Firewall provisioning state (az network firewall wait not reliable for hub FWs)
wait_for_firewall() {
    local fw_name=$1
    local rg=$2
    echo "  Waiting for Azure Firewall '$fw_name' (this takes 20-30 min)..."
    while true; do
        state=$(az network firewall show \
            --resource-group "$rg" \
            --name "$fw_name" \
            --query "provisioningState" -o tsv 2>/dev/null)
        if [ "$state" = "Succeeded" ]; then
            echo "  Azure Firewall '$fw_name' → Succeeded."
            break
        elif [ "$state" = "Failed" ]; then
            echo "ERROR: Azure Firewall '$fw_name' provisioning Failed. Exiting."
            exit 1
        fi
        echo "  State: ${state:-Pending} – rechecking in 60 seconds..."
        sleep 60
    done
}

# =============================================================================
# STEP 1 – Resource Group
# =============================================================================
echo ""
echo "=== Step 1: Creating Resource Group: $RG ($HUB1_LOCATION) ==="
az group create \
    --name "$RG" \
    --location "$HUB1_LOCATION" \
    --output none
check "Resource group create"

# =============================================================================
# STEP 2 – Virtual WAN
# =============================================================================
echo ""
echo "=== Step 2: Creating Virtual WAN: $VWAN ==="
az network vwan create \
    --resource-group "$RG" \
    --name "$VWAN" \
    --location "$HUB1_LOCATION" \
    --type Standard \
    --output none
check "Virtual WAN create"

# =============================================================================
# STEP 3 – Virtual Hubs (parallel, then wait)
# =============================================================================
echo ""
echo "=== Step 3: Creating Hub 1 and Hub 2 in parallel ==="

az network vhub create \
    --resource-group "$RG" \
    --name "$HUB1_NAME" \
    --vwan "$VWAN" \
    --location "$HUB1_LOCATION" \
    --address-prefix "$HUB1_CIDR" \
    --sku Standard \
    --no-wait \
    --output none

az network vhub create \
    --resource-group "$RG" \
    --name "$HUB2_NAME" \
    --vwan "$VWAN" \
    --location "$HUB2_LOCATION" \
    --address-prefix "$HUB2_CIDR" \
    --sku Standard \
    --no-wait \
    --output none

echo "Waiting for Hub 1 ($HUB1_NAME) to provision..."
az network vhub wait \
    --resource-group "$RG" \
    --name "$HUB1_NAME" \
    --created \
    --interval 30 \
    --timeout 1800
check "Hub 1 provisioning"

echo "Waiting for Hub 2 ($HUB2_NAME) to provision..."
az network vhub wait \
    --resource-group "$RG" \
    --name "$HUB2_NAME" \
    --created \
    --interval 30 \
    --timeout 1800
check "Hub 2 provisioning"
echo "Both hubs ready."

# =============================================================================
# STEP 4 – Spoke VNets
# =============================================================================
echo ""
echo "=== Step 4: Creating Spoke VNets ==="

az network vnet create \
    --resource-group "$RG" \
    --name "$SPOKE1_VNET" \
    --location "$HUB1_LOCATION" \
    --address-prefixes "$SPOKE1_CIDR" \
    --subnet-name "$SPOKE1_SUBNET" \
    --subnet-prefixes "$SPOKE1_SUBNET_CIDR" \
    --output none
check "Spoke 1 VNet create"

az network vnet create \
    --resource-group "$RG" \
    --name "$SPOKE2_VNET" \
    --location "$HUB2_LOCATION" \
    --address-prefixes "$SPOKE2_CIDR" \
    --subnet-name "$SPOKE2_SUBNET" \
    --subnet-prefixes "$SPOKE2_SUBNET_CIDR" \
    --output none
check "Spoke 2 VNet create"

# =============================================================================
# STEP 5 – NSGs (SSH from admin IP + ICMP from other spoke)
# =============================================================================
echo ""
echo "=== Step 5: Creating NSGs ==="

# NSG 1 (Spoke 1 – South Africa North)
az network nsg create \
    --resource-group "$RG" \
    --name "$NSG1" \
    --location "$HUB1_LOCATION" \
    --output none
check "NSG 1 create"

az network nsg rule create \
    --resource-group "$RG" \
    --nsg-name "$NSG1" \
    --name "Allow-SSH-Inbound" \
    --priority 100 \
    --direction Inbound \
    --source-address-prefixes "$MY_IP" \
    --source-port-ranges '*' \
    --destination-address-prefixes '*' \
    --destination-port-ranges 22 \
    --protocol Tcp \
    --access Allow \
    --description "Allow SSH from admin IP" \
    --output none
check "NSG 1 SSH rule"

az network nsg rule create \
    --resource-group "$RG" \
    --nsg-name "$NSG1" \
    --name "Allow-ICMP-From-Spoke2" \
    --priority 110 \
    --direction Inbound \
    --source-address-prefixes "$SPOKE2_CIDR" \
    --source-port-ranges '*' \
    --destination-address-prefixes '*' \
    --destination-port-ranges '*' \
    --protocol Icmp \
    --access Allow \
    --description "Allow ICMP ping from Spoke 2" \
    --output none
check "NSG 1 ICMP rule"

# NSG 2 (Spoke 2 – Northern Europe)
az network nsg create \
    --resource-group "$RG" \
    --name "$NSG2" \
    --location "$HUB2_LOCATION" \
    --output none
check "NSG 2 create"

az network nsg rule create \
    --resource-group "$RG" \
    --nsg-name "$NSG2" \
    --name "Allow-SSH-Inbound" \
    --priority 100 \
    --direction Inbound \
    --source-address-prefixes "$MY_IP" \
    --source-port-ranges '*' \
    --destination-address-prefixes '*' \
    --destination-port-ranges 22 \
    --protocol Tcp \
    --access Allow \
    --description "Allow SSH from admin IP" \
    --output none
check "NSG 2 SSH rule"

az network nsg rule create \
    --resource-group "$RG" \
    --nsg-name "$NSG2" \
    --name "Allow-ICMP-From-Spoke1" \
    --priority 110 \
    --direction Inbound \
    --source-address-prefixes "$SPOKE1_CIDR" \
    --source-port-ranges '*' \
    --destination-address-prefixes '*' \
    --destination-port-ranges '*' \
    --protocol Icmp \
    --access Allow \
    --description "Allow ICMP ping from Spoke 1" \
    --output none
check "NSG 2 ICMP rule"

# Associate NSGs with subnets
az network vnet subnet update \
    --resource-group "$RG" \
    --vnet-name "$SPOKE1_VNET" \
    --name "$SPOKE1_SUBNET" \
    --network-security-group "$NSG1" \
    --output none
check "NSG 1 subnet association"

az network vnet subnet update \
    --resource-group "$RG" \
    --vnet-name "$SPOKE2_VNET" \
    --name "$SPOKE2_SUBNET" \
    --network-security-group "$NSG2" \
    --output none
check "NSG 2 subnet association"

# =============================================================================
# STEP 6 – Azure Firewall Policies (Standard SKU)
# =============================================================================
echo ""
echo "=== Step 6: Creating Azure Firewall Policies ==="

az network firewall policy create \
    --resource-group "$RG" \
    --name "$FW_POLICY1_NAME" \
    --location "$HUB1_LOCATION" \
    --sku Standard \
    --output none
check "Firewall Policy 1 create"

az network firewall policy create \
    --resource-group "$RG" \
    --name "$FW_POLICY2_NAME" \
    --location "$HUB2_LOCATION" \
    --sku Standard \
    --output none
check "Firewall Policy 2 create"

# =============================================================================
# STEP 7 – Rule Collection Groups
# =============================================================================
echo ""
echo "=== Step 7: Creating Rule Collection Groups ==="

az network firewall policy rule-collection-group create \
    --resource-group "$RG" \
    --policy-name "$FW_POLICY1_NAME" \
    --name "$FW_RCG_NAME" \
    --priority 100 \
    --output none
check "Rule Collection Group 1 create"

az network firewall policy rule-collection-group create \
    --resource-group "$RG" \
    --policy-name "$FW_POLICY2_NAME" \
    --name "$FW_RCG_NAME" \
    --priority 100 \
    --output none
check "Rule Collection Group 2 create"

# =============================================================================
# STEP 8 – Network Rules: allow ICMP between both spoke CIDRs
# =============================================================================
echo ""
echo "=== Step 8: Adding ICMP allow rules to both Firewall Policies ==="

az network firewall policy rule-collection-group collection add-filter-collection \
    --resource-group "$RG" \
    --policy-name "$FW_POLICY1_NAME" \
    --rule-collection-group-name "$FW_RCG_NAME" \
    --name "AllowCrossSpokePing" \
    --collection-priority 100 \
    --action Allow \
    --rule-type NetworkRule \
    --rule-name "Allow-ICMP-Between-Spokes" \
    --ip-protocols ICMP \
    --source-addresses "$SPOKE1_CIDR" "$SPOKE2_CIDR" \
    --destination-addresses "$SPOKE1_CIDR" "$SPOKE2_CIDR" \
    --destination-ports '*' \
    --output none
check "Firewall Policy 1 ICMP rule"

az network firewall policy rule-collection-group collection add-filter-collection \
    --resource-group "$RG" \
    --policy-name "$FW_POLICY2_NAME" \
    --rule-collection-group-name "$FW_RCG_NAME" \
    --name "AllowCrossSpokePing" \
    --collection-priority 100 \
    --action Allow \
    --rule-type NetworkRule \
    --rule-name "Allow-ICMP-Between-Spokes" \
    --ip-protocols ICMP \
    --source-addresses "$SPOKE1_CIDR" "$SPOKE2_CIDR" \
    --destination-addresses "$SPOKE1_CIDR" "$SPOKE2_CIDR" \
    --destination-ports '*' \
    --output none
check "Firewall Policy 2 ICMP rule"

# =============================================================================
# STEP 9 – Get Hub Resource IDs (required for az network firewall create --vhub)
# =============================================================================
echo ""
echo "=== Step 9: Fetching Hub Resource IDs ==="

HUB1_ID=$(az network vhub show \
    --resource-group "$RG" \
    --name "$HUB1_NAME" \
    --query id -o tsv)
check "Hub 1 ID lookup"

HUB2_ID=$(az network vhub show \
    --resource-group "$RG" \
    --name "$HUB2_NAME" \
    --query id -o tsv)
check "Hub 2 ID lookup"

# =============================================================================
# STEP 10 – Azure Firewalls inside Hubs + VMs (all started in parallel)
#           Firewalls take 20-30 min; VMs finish first – overlap saves time
# =============================================================================
echo ""
echo "=== Step 10: Starting Azure Firewalls and VMs in parallel ==="

echo "  Starting Azure Firewall 1 ($AZF1_NAME) in $HUB1_LOCATION..."
az network firewall create \
    --resource-group "$RG" \
    --name "$AZF1_NAME" \
    --location "$HUB1_LOCATION" \
    --sku AZFW_Hub \
    --tier Standard \
    --vhub "$HUB1_ID" \
    --public-ip-count 1 \
    --firewall-policy "$FW_POLICY1_NAME" \
    --no-wait \
    --output none
check "Azure Firewall 1 create (no-wait)"

echo "  Starting Azure Firewall 2 ($AZF2_NAME) in $HUB2_LOCATION..."
az network firewall create \
    --resource-group "$RG" \
    --name "$AZF2_NAME" \
    --location "$HUB2_LOCATION" \
    --sku AZFW_Hub \
    --tier Standard \
    --vhub "$HUB2_ID" \
    --public-ip-count 1 \
    --firewall-policy "$FW_POLICY2_NAME" \
    --no-wait \
    --output none
check "Azure Firewall 2 create (no-wait)"

echo "  Starting VM 1 ($VM1_NAME) in $HUB1_LOCATION..."
az vm create \
    --resource-group "$RG" \
    --name "$VM1_NAME" \
    --location "$HUB1_LOCATION" \
    --image "$IMAGE" \
    --size "$VM_SIZE" \
    --vnet-name "$SPOKE1_VNET" \
    --subnet "$SPOKE1_SUBNET" \
    --admin-username "$ADMIN_USERNAME" \
    --admin-password "$ADMIN_PASSWORD" \
    --public-ip-sku Standard \
    --nsg "" \
    --no-wait \
    --output none
check "VM 1 create (no-wait)"

echo "  Starting VM 2 ($VM2_NAME) in $HUB2_LOCATION..."
az vm create \
    --resource-group "$RG" \
    --name "$VM2_NAME" \
    --location "$HUB2_LOCATION" \
    --image "$IMAGE" \
    --size "$VM_SIZE" \
    --vnet-name "$SPOKE2_VNET" \
    --subnet "$SPOKE2_SUBNET" \
    --admin-username "$ADMIN_USERNAME" \
    --admin-password "$ADMIN_PASSWORD" \
    --public-ip-sku Standard \
    --nsg "" \
    --no-wait \
    --output none
check "VM 2 create (no-wait)"

echo "Waiting for VM 1 to be ready..."
az vm wait \
    --resource-group "$RG" \
    --name "$VM1_NAME" \
    --created \
    --interval 15 \
    --timeout 900
check "VM 1 ready"

echo "Waiting for VM 2 to be ready..."
az vm wait \
    --resource-group "$RG" \
    --name "$VM2_NAME" \
    --created \
    --interval 15 \
    --timeout 900
check "VM 2 ready"
echo "Both VMs ready."

# Wait for firewalls (will still be provisioning)
wait_for_firewall "$AZF1_NAME" "$RG"
wait_for_firewall "$AZF2_NAME" "$RG"
echo "Both Azure Firewalls ready."

# =============================================================================
# STEP 11 – Routing Intent: PrivateTraffic → Azure Firewall on each hub
# =============================================================================
echo ""
echo "=== Step 11: Enabling Routing Intent on both hubs ==="

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

az network vhub routing-intent create \
    --resource-group "$RG" \
    --vhub "$HUB1_NAME" \
    --name "${HUB1_NAME}-RoutingIntent" \
    --routing-policies "[{name:PrivateTrafficPolicy,destinations:[PrivateTraffic],next-hop:$AZF1_ID}]" \
    --output none
check "Hub 1 Routing Intent"

az network vhub routing-intent create \
    --resource-group "$RG" \
    --vhub "$HUB2_NAME" \
    --name "${HUB2_NAME}-RoutingIntent" \
    --routing-policies "[{name:PrivateTrafficPolicy,destinations:[PrivateTraffic],next-hop:$AZF2_ID}]" \
    --output none
check "Hub 2 Routing Intent"

echo "Routing Intent enabled on both hubs."

# =============================================================================
# STEP 12 – Connect Spoke VNets to their Hubs
# =============================================================================
echo ""
echo "=== Step 12: Connecting Spoke VNets to Hubs ==="

SPOKE1_ID=$(az network vnet show \
    --resource-group "$RG" \
    --name "$SPOKE1_VNET" \
    --query id -o tsv)

SPOKE2_ID=$(az network vnet show \
    --resource-group "$RG" \
    --name "$SPOKE2_VNET" \
    --query id -o tsv)

az network vhub connection create \
    --resource-group "$RG" \
    --vhub-name "$HUB1_NAME" \
    --name "$SPOKE1_CONN" \
    --remote-vnet "$SPOKE1_ID" \
    --no-wait \
    --output none
check "Spoke 1 connection create"

az network vhub connection create \
    --resource-group "$RG" \
    --vhub-name "$HUB2_NAME" \
    --name "$SPOKE2_CONN" \
    --remote-vnet "$SPOKE2_ID" \
    --no-wait \
    --output none
check "Spoke 2 connection create"

echo "Waiting for Spoke 1 connection to complete..."
az network vhub connection wait \
    --resource-group "$RG" \
    --vhub-name "$HUB1_NAME" \
    --name "$SPOKE1_CONN" \
    --created \
    --interval 20 \
    --timeout 900
check "Spoke 1 connection ready"

echo "Waiting for Spoke 2 connection to complete..."
az network vhub connection wait \
    --resource-group "$RG" \
    --vhub-name "$HUB2_NAME" \
    --name "$SPOKE2_CONN" \
    --created \
    --interval 20 \
    --timeout 900
check "Spoke 2 connection ready"

# =============================================================================
# SUMMARY
# =============================================================================
VM1_PIP=$(az vm list-ip-addresses \
    --resource-group "$RG" \
    --name "$VM1_NAME" \
    --query "[].virtualMachine.network.publicIpAddresses[0].ipAddress" \
    -o tsv)

VM2_PIP=$(az vm list-ip-addresses \
    --resource-group "$RG" \
    --name "$VM2_NAME" \
    --query "[].virtualMachine.network.publicIpAddresses[0].ipAddress" \
    -o tsv)

VM1_PVT=$(az vm show \
    --resource-group "$RG" \
    --name "$VM1_NAME" \
    --show-details \
    --query "privateIps" -o tsv)

VM2_PVT=$(az vm show \
    --resource-group "$RG" \
    --name "$VM2_NAME" \
    --show-details \
    --query "privateIps" -o tsv)

# =============================================================================
# STEP 13 – Log Analytics Workspace
# =============================================================================
echo ""
echo "=== Step 13: Creating Log Analytics Workspaces (one per firewall) ==="

az monitor log-analytics workspace create \
    --resource-group "$RG" \
    --workspace-name "$LAW1_NAME" \
    --location "$HUB1_LOCATION" \
    --output none
check "Log Analytics Workspace 1 create"

LAW1_ID=$(az monitor log-analytics workspace show \
    --resource-group "$RG" \
    --workspace-name "$LAW1_NAME" \
    --query id -o tsv)
check "Log Analytics Workspace 1 ID lookup"
echo "  LAW 1 ready: $LAW1_NAME"

az monitor log-analytics workspace create \
    --resource-group "$RG" \
    --workspace-name "$LAW2_NAME" \
    --location "$HUB2_LOCATION" \
    --output none
check "Log Analytics Workspace 2 create"

LAW2_ID=$(az monitor log-analytics workspace show \
    --resource-group "$RG" \
    --workspace-name "$LAW2_NAME" \
    --query id -o tsv)
check "Log Analytics Workspace 2 ID lookup"
echo "  LAW 2 ready: $LAW2_NAME"

# =============================================================================
# STEP 14 – Diagnostic Settings on both Azure Firewalls
# Mode: Resource Specific (--export-to-resource-specific)
#   → Logs go to dedicated AZFW* tables, NOT the legacy AzureDiagnostics table
# Categories enabled:
#   AZFWNetworkRule     – every network rule hit (incl. ICMP) → AzNWTraffic
#   AZFWApplicationRule – application rule hits
#   AZFWNatRule         – DNAT rule hits
#   AZFWThreatIntel     – threat intelligence alerts
#   AZFWFlowTrace       – detailed per-flow trace
#   AZFWFatFlow         – high-throughput flow aggregation
#   AllMetrics          – throughput, SNAT port usage, health
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

echo "  Enabling diagnostics on $AZF1_NAME (Resource Specific → $LAW1_NAME)..."
az monitor diagnostic-settings create \
    --resource "$AZF1_ID" \
    --workspace "$LAW1_ID" \
    --name "$DIAG_NAME1" \
    --export-to-resource-specific \
    --logs '[{"category":"AZFWNetworkRule","enabled":true},{"category":"AZFWApplicationRule","enabled":true},{"category":"AZFWNatRule","enabled":true},{"category":"AZFWThreatIntel","enabled":true},{"category":"AZFWFlowTrace","enabled":true},{"category":"AZFWFatFlow","enabled":true}]' \
    --metrics '[{"category":"AllMetrics","enabled":true}]' \
    --output none
check "Firewall 1 diagnostic settings"
echo "  $AZF1_NAME diagnostics → enabled (Resource Specific)."

echo "  Enabling diagnostics on $AZF2_NAME (Resource Specific → $LAW2_NAME)..."
az monitor diagnostic-settings create \
    --resource "$AZF2_ID" \
    --workspace "$LAW2_ID" \
    --name "$DIAG_NAME2" \
    --export-to-resource-specific \
    --logs '[{"category":"AZFWNetworkRule","enabled":true},{"category":"AZFWApplicationRule","enabled":true},{"category":"AZFWNatRule","enabled":true},{"category":"AZFWThreatIntel","enabled":true},{"category":"AZFWFlowTrace","enabled":true},{"category":"AZFWFatFlow","enabled":true}]' \
    --metrics '[{"category":"AllMetrics","enabled":true}]' \
    --output none
check "Firewall 2 diagnostic settings"
echo "  $AZF2_NAME diagnostics → enabled (Resource Specific)."

echo ""
echo "==============================================================================="
echo " Deployment Complete!"
echo "==============================================================================="
echo ""
echo " Resource Group  : $RG"
echo " Virtual WAN     : $VWAN"
echo ""
echo " Hub 1 : $HUB1_NAME ($HUB1_LOCATION)  CIDR: $HUB1_CIDR"
echo " Hub 2 : $HUB2_NAME ($HUB2_LOCATION)    CIDR: $HUB2_CIDR"
echo ""
echo " Azure Firewall 1 : $AZF1_NAME  →  Policy: $FW_POLICY1_NAME"
echo " Azure Firewall 2 : $AZF2_NAME  →  Policy: $FW_POLICY2_NAME"
echo " Routing Intent   : PrivateTraffic → Azure Firewall (both hubs)"
echo " Firewall Rule    : Allow ICMP  $SPOKE1_CIDR ↔ $SPOKE2_CIDR"
echo ""
echo " Spoke 1 : $SPOKE1_VNET ($SPOKE1_CIDR)  → $HUB1_NAME"
echo " Spoke 2 : $SPOKE2_VNET ($SPOKE2_CIDR)  → $HUB2_NAME"
echo ""
echo " VM 1 : $VM1_NAME"
echo "   Public IP  : $VM1_PIP"
echo "   Private IP : $VM1_PVT"
echo "   SSH        : ssh $ADMIN_USERNAME@$VM1_PIP"
echo ""
echo " VM 2 : $VM2_NAME"
echo "   Public IP  : $VM2_PIP"
echo "   Private IP : $VM2_PVT"
echo "   SSH        : ssh $ADMIN_USERNAME@$VM2_PIP"
echo ""
echo " SSH access restricted to : $MY_IP"
echo ""
echo " Cross-hub ping test:"
echo "   From VM1 → ssh $ADMIN_USERNAME@$VM1_PIP  then:  ping $VM2_PVT"
echo "   From VM2 → ssh $ADMIN_USERNAME@$VM2_PIP  then:  ping $VM1_PVT"
echo ""
echo " Diagnostics (Resource Specific mode – AZFW* tables):"
echo "   FW1 Log Analytics Workspace : $LAW1_NAME (southafricanorth)"
echo "   FW2 Log Analytics Workspace : $LAW2_NAME (northeurope)"
echo "   Diag setting FW1            : $DIAG_NAME1"
echo "   Diag setting FW2            : $DIAG_NAME2"
echo ""
echo " NOTE: Allow 5-10 min for first logs to appear in Log Analytics."
echo ""
echo " KQL – ICMP traffic (Resource Specific table, run in each LAW):"
echo '   AZFWNetworkRule'
echo '   | where Protocol == "ICMP"'
echo '   | project TimeGenerated, SourceIp, DestinationIp, Action'
echo '   | order by TimeGenerated desc'
echo ""
echo " KQL – All network rule hits:"
echo '   AZFWNetworkRule'
echo '   | summarize count() by SourceIp, DestinationIp, Protocol, Action'
echo '   | order by count_ desc'
echo "==============================================================================="
