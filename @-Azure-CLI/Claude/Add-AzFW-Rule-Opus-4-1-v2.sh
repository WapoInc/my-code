#!/bin/bash

# Variables
RESOURCE_GROUP="Claude-AzFW-Bastion-With-Policies-2"
VNET_NAME="Claude-AzFW-Bastion-vnet"

#=================================================================================================================================================
# Create Resource Group and VNet
#=================================================================================================================================================
echo "Checking if Resource Group exists..."
if ! az group show --name $RESOURCE_GROUP &>/dev/null; then
    echo "Creating Resource Group: $RESOURCE_GROUP"
    az group create --name $RESOURCE_GROUP --location southafricanorth
else
    echo "Resource Group $RESOURCE_GROUP already exists, skipping..."
fi

echo "Checking if VNet exists..."
if ! az network vnet show --resource-group $RESOURCE_GROUP --name $VNET_NAME &>/dev/null; then
    echo "Creating VNet: $VNET_NAME"
    az network vnet create --resource-group $RESOURCE_GROUP --name $VNET_NAME --address-prefixes 10.40.0.0/22
else
    echo "VNet $VNET_NAME already exists, skipping..."
fi

#=================================================================================================================================================
# Create Subnets
#=================================================================================================================================================
echo "Checking if AzureFirewallSubnet exists..."
if ! az network vnet subnet show --resource-group $RESOURCE_GROUP --vnet-name $VNET_NAME --name AzureFirewallSubnet &>/dev/null; then
    echo "Creating AzureFirewallSubnet..."
    az network vnet subnet create --resource-group $RESOURCE_GROUP --vnet-name $VNET_NAME --name AzureFirewallSubnet --address-prefixes 10.40.0.0/26
else
    echo "AzureFirewallSubnet already exists, skipping..."
fi

echo "Checking if GatewaySubnet exists..."
if ! az network vnet subnet show --resource-group $RESOURCE_GROUP --vnet-name $VNET_NAME --name GatewaySubnet &>/dev/null; then
    echo "Creating GatewaySubnet..."
    az network vnet subnet create --resource-group $RESOURCE_GROUP --vnet-name $VNET_NAME --name GatewaySubnet --address-prefixes 10.40.0.64/26
else
    echo "GatewaySubnet already exists, skipping..."
fi

echo "Checking if AzureBastionSubnet exists..."
if ! az network vnet subnet show --resource-group $RESOURCE_GROUP --vnet-name $VNET_NAME --name AzureBastionSubnet &>/dev/null; then
    echo "Creating AzureBastionSubnet..."
    az network vnet subnet create --resource-group $RESOURCE_GROUP --vnet-name $VNET_NAME --name AzureBastionSubnet --address-prefixes 10.40.0.128/26
else
    echo "AzureBastionSubnet already exists, skipping..."
fi

echo "Checking if Hub subnet exists..."
if ! az network vnet subnet show --resource-group $RESOURCE_GROUP --vnet-name $VNET_NAME --name Hub &>/dev/null; then
    echo "Creating Hub subnet..."
    az network vnet subnet create --resource-group $RESOURCE_GROUP --vnet-name $VNET_NAME --name Hub --address-prefixes 10.40.1.0/24
else
    echo "Hub subnet already exists, skipping..."
fi

#=================================================================================================================================================
# Create Public IPs
#=================================================================================================================================================
echo "Checking if firewall public IP exists..."
if ! az network public-ip show --resource-group $RESOURCE_GROUP --name firewall-ip &>/dev/null; then
    echo "Creating firewall public IP..."
    az network public-ip create --resource-group $RESOURCE_GROUP --name firewall-ip --allocation-method Static --sku Standard
else
    echo "Firewall public IP already exists, skipping..."
fi

echo "Checking if bastion public IP exists..."
if ! az network public-ip show --resource-group $RESOURCE_GROUP --name bastion-ip &>/dev/null; then
    echo "Creating bastion public IP..."
    az network public-ip create --resource-group $RESOURCE_GROUP --name bastion-ip --allocation-method Static --sku Standard
else
    echo "Bastion public IP already exists, skipping..."
fi

#=================================================================================================================================================
# Create Azure Firewall first (without policy)
#=================================================================================================================================================
echo "Checking if Azure Firewall exists..."
if ! az network firewall show --resource-group $RESOURCE_GROUP --name AzFW-Claude &>/dev/null; then
    echo "Creating Azure Firewall..."
    az network firewall create --resource-group $RESOURCE_GROUP --name AzFW-Claude --location southafricanorth
    echo "Creating firewall IP configuration..."
    az network firewall ip-config create --resource-group $RESOURCE_GROUP --firewall-name AzFW-Claude --name config --public-ip-address firewall-ip --vnet-name $VNET_NAME
else
    echo "Azure Firewall already exists, skipping creation..."
    # Check if IP config exists
    if ! az network firewall ip-config show --resource-group $RESOURCE_GROUP --firewall-name AzFW-Claude --name config &>/dev/null; then
        echo "Creating firewall IP configuration..."
        az network firewall ip-config create --resource-group $RESOURCE_GROUP --firewall-name AzFW-Claude --name config --public-ip-address firewall-ip --vnet-name $VNET_NAME
    else
        echo "Firewall IP configuration already exists, skipping..."
    fi
fi

#=================================================================================================================================================
# Create Azure Firewall Policy after firewall creation
#=================================================================================================================================================
echo "Checking if Azure Firewall Policy exists..."
if ! az network firewall policy show --resource-group $RESOURCE_GROUP --name AzFW-Policy &>/dev/null; then
    echo "Creating Azure Firewall Policy..."
    az network firewall policy create --resource-group $RESOURCE_GROUP --name AzFW-Policy --location southafricanorth --sku Standard
else
    echo "Azure Firewall Policy already exists, skipping..."
fi

echo "Checking if NetworkRuleCollectionGroup exists..."
if ! az network firewall policy rule-collection-group show --resource-group $RESOURCE_GROUP --policy-name AzFW-Policy --name NetworkRuleCollectionGroup &>/dev/null; then
    echo "Creating NetworkRuleCollectionGroup..."
    az network firewall policy rule-collection-group create --resource-group $RESOURCE_GROUP --policy-name AzFW-Policy --name NetworkRuleCollectionGroup --priority 200
else
    echo "NetworkRuleCollectionGroup already exists, skipping..."
fi

#=================================================================================================================================================
# Add RDP rule to allow traffic from 192.168.2.0/24 to 10.40.0.0/22
#=================================================================================================================================================
echo "Checking if RDP rule collection exists..."
if ! az network firewall policy rule-collection-group collection show --resource-group $RESOURCE_GROUP --policy-name AzFW-Policy --rule-collection-group-name NetworkRuleCollectionGroup --name AllowRDPCollection &>/dev/null; then
    echo "Creating RDP rule collection..."
    az network firewall policy rule-collection-group collection add-filter-collection \
        --resource-group $RESOURCE_GROUP \
        --policy-name AzFW-Policy \
        --rule-collection-group-name NetworkRuleCollectionGroup \
        --name AllowRDPCollection \
        --collection-priority 100 \
        --action Allow \
        --rule-name AllowRDPFromOnPrem \
        --rule-type NetworkRule \
        --source-addresses "192.168.2.0/24" \
        --destination-addresses "10.40.0.0/22" \
        --destination-ports "3389" \
        --ip-protocols "TCP"
else
    echo "RDP rule collection already exists, skipping..."
fi

#=================================================================================================================================================
# Add SSH rule to allow traffic from 192.168.2.0/24 to 10.40.0.0/22
#=================================================================================================================================================
echo "Checking if SSH rule collection exists..."
if ! az network firewall policy rule-collection-group collection show --resource-group $RESOURCE_GROUP --policy-name AzFW-Policy --rule-collection-group-name NetworkRuleCollectionGroup --name AllowSSHCollection &>/dev/null; then
    echo "Creating SSH rule collection..."
    az network firewall policy rule-collection-group collection add-filter-collection \
        --resource-group $RESOURCE_GROUP \
        --policy-name AzFW-Policy \
        --rule-collection-group-name NetworkRuleCollectionGroup \
        --name AllowSSHCollection \
        --collection-priority 110 \
        --action Allow \
        --rule-name AllowSSHFromOnPrem \
        --rule-type NetworkRule \
        --source-addresses "192.168.2.0/24" \
        --destination-addresses "10.40.0.0/22" \
        --destination-ports "22" \
        --ip-protocols "TCP"
else
    echo "SSH rule collection already exists, skipping..."
fi

#=================================================================================================================================================
# Add HTTPS rule to allow traffic from 192.168.2.0/24 to 10.40.0.0/22
#=================================================================================================================================================
echo "Checking if HTTPS rule collection exists..."
if ! az network firewall policy rule-collection-group collection show --resource-group $RESOURCE_GROUP --policy-name AzFW-Policy --rule-collection-group-name NetworkRuleCollectionGroup --name AllowHTTPSCollection &>/dev/null; then
    echo "Creating HTTPS rule collection..."
    az network firewall policy rule-collection-group collection add-filter-collection \
        --resource-group $RESOURCE_GROUP \
        --policy-name AzFW-Policy \
        --rule-collection-group-name NetworkRuleCollectionGroup \
        --name AllowHTTPSCollection \
        --collection-priority 120 \
        --action Allow \
        --rule-name AllowHTTPSFromOnPrem \
        --rule-type NetworkRule \
        --source-addresses "192.168.2.0/24" \
        --destination-addresses "10.40.0.0/22" \
        --destination-ports "443" \
        --ip-protocols "TCP"
else
    echo "HTTPS rule collection already exists, skipping..."
fi

#=================================================================================================================================================
# Associate policy with firewall (after both are created)
#=================================================================================================================================================
echo "Checking if firewall policy is associated..."
CURRENT_POLICY=$(az network firewall show --resource-group $RESOURCE_GROUP --name AzFW-Claude --query "firewallPolicy.id" -o tsv 2>/dev/null)
POLICY_ID=$(az network firewall policy show --resource-group $RESOURCE_GROUP --name AzFW-Policy --query id --output tsv)

if [[ "$CURRENT_POLICY" != "$POLICY_ID" ]]; then
    echo "Associating policy with firewall..."
    az network firewall update --resource-group $RESOURCE_GROUP --name AzFW-Claude --firewall-policy $POLICY_ID
else
    echo "Firewall policy already associated, skipping..."
fi

#=================================================================================================================================================
# Create Bastion
#=================================================================================================================================================
echo "Checking if Azure Bastion exists..."
if ! az network bastion show --resource-group $RESOURCE_GROUP --name Claude-Bastion &>/dev/null; then
    echo "Creating Azure Bastion..."
    az network bastion create --resource-group $RESOURCE_GROUP --name Claude-Bastion --public-ip-address bastion-ip --vnet-name $VNET_NAME
else
    echo "Azure Bastion already exists, skipping..."
fi

#=================================================================================================================================================
# Create VM
#=================================================================================================================================================
echo "Checking if VM exists..."
if ! az vm show --resource-group $RESOURCE_GROUP --name Hub-VM &>/dev/null; then
    echo "Creating VM..."
    az vm create --resource-group $RESOURCE_GROUP --name Hub-VM --image Ubuntu2204 --size Standard_B2s --vnet-name $VNET_NAME --subnet Hub --admin-username rootadmin --admin-password 'P@ssw0rd123!' --authentication-type password --no-wait
else
    echo "VM Hub-VM already exists, skipping..."
fi

echo "Deployment completed with RDP, SSH, and HTTPS network rules!"