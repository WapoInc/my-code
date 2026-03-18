#!/bin/bash

###################################################################
#                                                                 #
# Purpose: Create an Azure Application Gateway v2 (WAF_v2)       #
#          with VNet, Subnet, Public IP, Backend Pool,            #
#          HTTP Settings, Listener and Routing Rule               #
# Language: Azure CLI (bash)                                      #
# Built: 18/03/2026                                               #
###################################################################

set -e  # Exit immediately on any error

# ---------------------------------------------------------------
# VARIABLES - Edit these before running
# ---------------------------------------------------------------
SUBSCRIPTION_ID="0cfd0d2a-2b38-4c93-ba14-cf79185bc683"                        # Your Azure Subscription ID
RESOURCE_GROUP="rg-appgw-demo"
LOCATION="southafricanorth"
DEPLOYMENT_NAME="appgw-demo"

VNET_NAME="vnet-${DEPLOYMENT_NAME}"
VNET_PREFIX="10.0.0.0/16"

APPGW_SUBNET_NAME="snet-appgw"
APPGW_SUBNET_PREFIX="10.0.1.0/24"         # /24 minimum recommended for AppGW

BACKEND_SUBNET_NAME="snet-backend"
BACKEND_SUBNET_PREFIX="10.0.2.0/24"

PUBLIC_IP_NAME="pip-${DEPLOYMENT_NAME}"
APPGW_NAME="appgw-${DEPLOYMENT_NAME}"
WAF_POLICY_NAME="wafpol-${DEPLOYMENT_NAME}"

# Backend pool - add your backend server IPs or FQDNs here
BACKEND_ADDRESS="10.0.2.10"              # Replace with your backend IP or FQDN

# ---------------------------------------------------------------
# COLOURS
# ---------------------------------------------------------------
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ---------------------------------------------------------------
# VALIDATE SUBSCRIPTION ID
# ---------------------------------------------------------------
if [[ -z "$SUBSCRIPTION_ID" ]]; then
    error "SUBSCRIPTION_ID is not set. Please edit the variables section."
fi

# ---------------------------------------------------------------
# SET SUBSCRIPTION CONTEXT
# ---------------------------------------------------------------
info "Setting subscription context..."
az account set --subscription "$SUBSCRIPTION_ID"
success "Subscription set: $SUBSCRIPTION_ID"

# ---------------------------------------------------------------
# RESOURCE GROUP
# ---------------------------------------------------------------
info "Creating Resource Group: $RESOURCE_GROUP..."
if az group show --name "$RESOURCE_GROUP" &>/dev/null; then
    warn "Resource group '$RESOURCE_GROUP' already exists. Skipping."
else
    az group create \
        --name "$RESOURCE_GROUP" \
        --location "$LOCATION"
    success "Resource group created."
fi

# ---------------------------------------------------------------
# VIRTUAL NETWORK
# ---------------------------------------------------------------
info "Creating VNet: $VNET_NAME..."
if az network vnet show --resource-group "$RESOURCE_GROUP" --name "$VNET_NAME" &>/dev/null; then
    warn "VNet '$VNET_NAME' already exists. Skipping."
else
    az network vnet create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$VNET_NAME" \
        --location "$LOCATION" \
        --address-prefix "$VNET_PREFIX" \
        --subnet-name "$APPGW_SUBNET_NAME" \
        --subnet-prefix "$APPGW_SUBNET_PREFIX"
    success "VNet created."
fi

# ---------------------------------------------------------------
# APPGW SUBNET DELEGATION (required for NetworkIsolation on AppGW v2)
# ---------------------------------------------------------------
info "Ensuring subnet delegation on $APPGW_SUBNET_NAME..."
az network vnet subnet update \
    --resource-group "$RESOURCE_GROUP" \
    --vnet-name "$VNET_NAME" \
    --name "$APPGW_SUBNET_NAME" \
    --delegations Microsoft.Network/applicationGateways
success "Subnet delegation set: Microsoft.Network/applicationGateways"

# ---------------------------------------------------------------
# BACKEND SUBNET
# ---------------------------------------------------------------
info "Creating backend subnet: $BACKEND_SUBNET_NAME..."
if az network vnet subnet show --resource-group "$RESOURCE_GROUP" --vnet-name "$VNET_NAME" --name "$BACKEND_SUBNET_NAME" &>/dev/null; then
    warn "Backend subnet already exists. Skipping."
else
    az network vnet subnet create \
        --resource-group "$RESOURCE_GROUP" \
        --vnet-name "$VNET_NAME" \
        --name "$BACKEND_SUBNET_NAME" \
        --address-prefix "$BACKEND_SUBNET_PREFIX"
    success "Backend subnet created."
fi

# ---------------------------------------------------------------
# PUBLIC IP (Standard SKU required for AppGW v2)
# ---------------------------------------------------------------
info "Creating Public IP: $PUBLIC_IP_NAME..."
if az network public-ip show --resource-group "$RESOURCE_GROUP" --name "$PUBLIC_IP_NAME" &>/dev/null; then
    warn "Public IP '$PUBLIC_IP_NAME' already exists. Skipping."
else
    az network public-ip create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$PUBLIC_IP_NAME" \
        --location "$LOCATION" \
        --sku Standard \
        --allocation-method Static \
        --zone 1 2 3
    success "Public IP created."
fi

PUBLIC_IP=$(az network public-ip show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$PUBLIC_IP_NAME" \
    --query ipAddress -o tsv)
info "Public IP Address: $PUBLIC_IP"

# ---------------------------------------------------------------
# WAF POLICY (required for WAF_v2 SKU)
# ---------------------------------------------------------------
info "Creating WAF Policy: $WAF_POLICY_NAME..."
if az network application-gateway waf-policy show --resource-group "$RESOURCE_GROUP" --name "$WAF_POLICY_NAME" &>/dev/null; then
    warn "WAF Policy '$WAF_POLICY_NAME' already exists. Skipping."
else
    az network application-gateway waf-policy create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$WAF_POLICY_NAME" \
        --location "$LOCATION" \
        --type OWASP \
        --version 3.2
    # Set WAF Policy to Detection mode (change to Prevention when ready)
    az network application-gateway waf-policy policy-setting update \
        --policy-name "$WAF_POLICY_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --mode Detection \
        --state Enabled \
        --request-body-check true
    success "WAF Policy created in Detection mode."
fi

WAF_POLICY_ID=$(az network application-gateway waf-policy show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$WAF_POLICY_NAME" \
    --query id -o tsv)

# ---------------------------------------------------------------
# APPLICATION GATEWAY v2 (WAF_v2 SKU)
# ---------------------------------------------------------------
info "Creating Application Gateway v2: $APPGW_NAME..."
info "  SKU        : WAF_v2"
info "  Capacity   : 2 (autoscale min)"
info "  Location   : $LOCATION"

if az network application-gateway show --resource-group "$RESOURCE_GROUP" --name "$APPGW_NAME" &>/dev/null; then
    warn "Application Gateway '$APPGW_NAME' already exists. Skipping."
else
    az network application-gateway create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$APPGW_NAME" \
        --location "$LOCATION" \
        --sku WAF_v2 \
        --capacity 2 \
        --vnet-name "$VNET_NAME" \
        --subnet "$APPGW_SUBNET_NAME" \
        --public-ip-address "$PUBLIC_IP_NAME" \
        --http-settings-cookie-based-affinity Disabled \
        --http-settings-port 80 \
        --http-settings-protocol Http \
        --frontend-port 80 \
        --routing-rule-type Basic \
        --priority 100 \
        --servers "$BACKEND_ADDRESS" \
        --waf-policy "$WAF_POLICY_ID" \
        --min-capacity 1 \
        --max-capacity 10
    success "Application Gateway v2 created."
fi

# ---------------------------------------------------------------
# ENABLE AUTOSCALING
# ---------------------------------------------------------------
info "Verifying autoscale configuration..."
az network application-gateway update \
    --resource-group "$RESOURCE_GROUP" \
    --name "$APPGW_NAME" \
    --min-capacity 1 \
    --max-capacity 10 \
    --set sku.capacity=null
success "Autoscale configured: min=1, max=10"

# ---------------------------------------------------------------
# DIAGNOSTICS - Enable access logs to a storage account (optional)
# Uncomment and set STORAGE_ACCOUNT_ID to enable
# ---------------------------------------------------------------
# STORAGE_ACCOUNT_ID=""
# APPGW_ID=$(az network application-gateway show \
#     --resource-group "$RESOURCE_GROUP" \
#     --name "$APPGW_NAME" \
#     --query id -o tsv)
# az monitor diagnostic-settings create \
#     --name "diag-${APPGW_NAME}" \
#     --resource "$APPGW_ID" \
#     --storage-account "$STORAGE_ACCOUNT_ID" \
#     --logs '[{"category":"ApplicationGatewayAccessLog","enabled":true},{"category":"ApplicationGatewayFirewallLog","enabled":true}]' \
#     --metrics '[{"category":"AllMetrics","enabled":true}]'

# ---------------------------------------------------------------
# SUMMARY
# ---------------------------------------------------------------
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Application Gateway v2 Build Complete ${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "  Resource Group  : $RESOURCE_GROUP"
echo -e "  App Gateway     : $APPGW_NAME"
echo -e "  SKU             : WAF_v2"
echo -e "  Public IP       : $PUBLIC_IP"
echo -e "  WAF Policy      : $WAF_POLICY_NAME (Detection mode)"
echo -e "  Backend Pool    : $BACKEND_ADDRESS"
echo -e "  Autoscale       : min=1, max=10"
echo -e "${YELLOW}  NOTE: Switch WAF to Prevention mode when ready for production${NC}"
echo ""
