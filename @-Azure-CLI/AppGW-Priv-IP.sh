#!/bin/bash

#################################################################################
# Azure Application Gateway Creation Script
# Description: Creates an Azure Application Gateway with all required resources
# Author: Generated Script
# Date: 2025-10-17
#################################################################################

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

#################################################################################
# Configuration Variables - Modify these as needed
#################################################################################

RESOURCE_GROUP="rg-appgateway-demo5"
LOCATION="southafricanorth"
VNET_NAME="vnet-appgateway"
VNET_ADDRESS_PREFIX="10.0.0.0/16"
SUBNET_NAME="subnet-appgateway"
SUBNET_ADDRESS_PREFIX="10.0.1.0/24"
APP_GATEWAY_NAME="appgw-demo"
SKU="WAF_v2"
CAPACITY=2
FRONTEND_PORT=80
BACKEND_PORT=80
PRIVATE_IP_ADDRESS="10.0.1.10"  # Static private IP for the Application Gateway

# WAF Configuration
WAF_MODE="Prevention"  # Options: Detection, Prevention
WAF_RULE_SET_TYPE="OWASP"
WAF_RULE_SET_VERSION="3.2"
WAF_ENABLED="true"

# Tags (optional)
TAGS="Environment=Demo Project=AppGateway"

#################################################################################
# Pre-flight Checks
#################################################################################

print_info "Starting Azure Application Gateway deployment..."

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    print_error "Azure CLI is not installed. Please install it first."
    exit 1
fi

# Check if logged in to Azure
print_info "Checking Azure CLI authentication..."
if ! az account show &> /dev/null; then
    print_error "Not logged in to Azure. Please run 'az login' first."
    exit 1
fi

# Display current subscription
SUBSCRIPTION=$(az account show --query name -o tsv)
print_info "Using subscription: $SUBSCRIPTION"

#################################################################################
# Create Resource Group
#################################################################################

print_info "Creating resource group: $RESOURCE_GROUP in $LOCATION..."
az group create \
    --name "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --tags $TAGS

#################################################################################
# Create Virtual Network and Subnet
#################################################################################

print_info "Creating virtual network: $VNET_NAME..."
az network vnet create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VNET_NAME" \
    --address-prefix "$VNET_ADDRESS_PREFIX" \
    --location "$LOCATION" \
    --tags $TAGS

print_info "Creating subnet: $SUBNET_NAME..."
az network vnet subnet create \
    --resource-group "$RESOURCE_GROUP" \
    --vnet-name "$VNET_NAME" \
    --name "$SUBNET_NAME" \
    --address-prefix "$SUBNET_ADDRESS_PREFIX" \
    --delegations "Microsoft.Network/applicationGateways"

print_info "Subnet delegated to Microsoft.Network/applicationGateways"

#################################################################################
# Create WAF Policy
#################################################################################

WAF_POLICY_NAME="${APP_GATEWAY_NAME}-waf-policy"
print_info "Creating WAF Policy: $WAF_POLICY_NAME..."

az network application-gateway waf-policy create \
    --name "$WAF_POLICY_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --type "$WAF_RULE_SET_TYPE" \
    --version "$WAF_RULE_SET_VERSION" \
    --tags $TAGS

print_info "Setting WAF Policy mode to $WAF_MODE..."
az network application-gateway waf-policy policy-setting update \
    --policy-name "$WAF_POLICY_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --mode "$WAF_MODE" \
    --state Enabled

#################################################################################
# Create Application Gateway with WAF v2 and Private IP
#################################################################################

print_info "Creating Application Gateway: $APP_GATEWAY_NAME with WAF v2 and private IP..."
print_warning "This may take 5-10 minutes..."

# Create the Application Gateway with WAF v2, WAF policy, and private IP
az network application-gateway create \
    --name "$APP_GATEWAY_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --vnet-name "$VNET_NAME" \
    --subnet "$SUBNET_NAME" \
    --capacity "$CAPACITY" \
    --sku "$SKU" \
    --http-settings-cookie-based-affinity Disabled \
    --frontend-port "$FRONTEND_PORT" \
    --http-settings-port "$BACKEND_PORT" \
    --http-settings-protocol Http \
    --private-ip-address "$PRIVATE_IP_ADDRESS" \
    --waf-policy "$WAF_POLICY_NAME" \
    --priority 100 \
    --tags $TAGS

print_info "Application Gateway created with private IP: $PRIVATE_IP_ADDRESS"
print_info "WAF v2 enabled in $WAF_MODE mode with $WAF_RULE_SET_TYPE $WAF_RULE_SET_VERSION ruleset"

#################################################################################
# Display Results
#################################################################################

print_info "Deployment completed successfully!"
echo ""
print_info "Resource Details:"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  Application Gateway: $APP_GATEWAY_NAME"
echo "  SKU: $SKU"
echo "  Location: $LOCATION"
echo "  Private IP Address: $PRIVATE_IP_ADDRESS"
echo "  WAF Policy: $WAF_POLICY_NAME"
echo "  WAF Mode: $WAF_MODE"
echo "  WAF Rule Set: $WAF_RULE_SET_TYPE $WAF_RULE_SET_VERSION"
echo ""

print_info "Next Steps:"
echo "  1. Add backend pool targets using:"
echo "     az network application-gateway address-pool update"
echo "  2. Configure health probes if needed"
echo "  3. Add additional routing rules as required"
echo "  4. Configure SSL certificates for HTTPS"
echo "  5. Set up VPN or ExpressRoute to access this internal Application Gateway"
echo "  6. Review and customize WAF rules if needed"
echo "  7. Monitor WAF logs in Azure Monitor"
echo ""

print_info "To view your Application Gateway:"
echo "  az network application-gateway show --name $APP_GATEWAY_NAME --resource-group $RESOURCE_GROUP"
echo ""

print_info "To delete all resources created by this script:"
echo "  az group delete --name $RESOURCE_GROUP --yes --no-wait"