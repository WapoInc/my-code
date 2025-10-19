#!/bin/bash

# Variables
RESOURCE_GROUP="Claude-AzFW-Bastion-With-Policies-1"
VNET_NAME="Claude-AzFW-Bastion-vnet"
#=================================================================================================================================================
# Create Resource Group and VNet
#=================================================================================================================================================
az group create --name $RESOURCE_GROUP --location southafricanorth
az network vnet create --resource-group $RESOURCE_GROUP --name $VNET_NAME --address-prefixes 10.40.0.0/22

#=================================================================================================================================================
# Create Subnets
#=================================================================================================================================================
az network vnet subnet create --resource-group $RESOURCE_GROUP --vnet-name $VNET_NAME --name AzureFirewallSubnet --address-prefixes 10.40.0.0/26
az network vnet subnet create --resource-group $RESOURCE_GROUP --vnet-name $VNET_NAME --name GatewaySubnet --address-prefixes 10.40.0.64/26
az network vnet subnet create --resource-group $RESOURCE_GROUP --vnet-name $VNET_NAME --name AzureBastionSubnet --address-prefixes 10.40.0.128/26
az network vnet subnet create --resource-group $RESOURCE_GROUP --vnet-name $VNET_NAME --name Hub --address-prefixes 10.40.1.0/24

#=================================================================================================================================================
# Create Public IPs
#=================================================================================================================================================
az network public-ip create --resource-group $RESOURCE_GROUP --name firewall-ip --allocation-method Static --sku Standard
az network public-ip create --resource-group $RESOURCE_GROUP --name bastion-ip --allocation-method Static --sku Standard

#=================================================================================================================================================
# Create Azure Firewall first (without policy)
#=================================================================================================================================================
az network firewall create --resource-group $RESOURCE_GROUP --name AzFW-Claude --location southafricanorth
az network firewall ip-config create --resource-group $RESOURCE_GROUP --firewall-name AzFW-Claude --name config --public-ip-address firewall-ip --vnet-name $VNET_NAME

#=================================================================================================================================================
# Create Azure Firewall Policy after firewall creation
#=================================================================================================================================================
az network firewall policy create --resource-group $RESOURCE_GROUP --name AzFW-Policy --location southafricanorth --sku Standard
az network firewall policy rule-collection-group create --resource-group $RESOURCE_GROUP --policy-name AzFW-Policy --name NetworkRuleCollectionGroup --priority 200

#=================================================================================================================================================
# Add RDP rule to allow traffic from 192.168.2.0/24 to 10.40.0.0/22
#=================================================================================================================================================
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

#=================================================================================================================================================
# Associate policy with firewall (after both are created)
#=================================================================================================================================================
POLICY_ID=$(az network firewall policy show --resource-group $RESOURCE_GROUP --name AzFW-Policy --query id --output tsv)
az network firewall update --resource-group $RESOURCE_GROUP --name AzFW-Claude --firewall-policy $POLICY_ID

#=================================================================================================================================================
# Create Bastion
#=================================================================================================================================================
az network bastion create --resource-group $RESOURCE_GROUP --name Claude-Bastion --public-ip-address bastion-ip --vnet-name $VNET_NAME

#=================================================================================================================================================
# Create VM
#=================================================================================================================================================
az vm create --resource-group $RESOURCE_GROUP --name Hub-VM --image Ubuntu2204 --size Standard_B2s --vnet-name $VNET_NAME --subnet Hub --admin-username rootadmin --admin-password 'P@ssw0rd123!' --authentication-type password --no-wait



echo "Deployment completed with multiple RDP network rules!"