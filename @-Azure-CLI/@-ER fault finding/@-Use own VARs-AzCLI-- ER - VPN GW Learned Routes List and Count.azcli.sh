#!/usr/bin/env bash
#vmr
set -euo pipefail
# AI prompt
#==============================================================================================
#================================================================================================
extract the variables , and show the az commands
list the variables , left flush and show the 2 az commands in the same page
add the variables and the az commands on same page
use format of az commadn as all on the same line
#================================================================================================
RG="Enter your Resource Group name"
GateWayName="Enter your ER or VPN Gateway name"
ER_Circuit_Name="Enter your ER Circuit name"

az network vnet-gateway list-learned-routes --resource-group "$RG" --name "$GateWayName" -o table
az network express-route show --resource-group "$RG" --name "$ER_Circuit_Name" -o table
#=================================================================================================
#=================================================================================================

# Login to Azure
az login --tenant MngEnv461963.onmicrosoft.com
az account set --subscription "viresent New AIRS"
az account show -o table

az account list -o table
az account set --subscription "Enter your Sub name"


#--------------------------------------------------------------------------------------
#Enter your variables
RG="Enter your Resource Group name"
GateWayName="Enter your ER or VPN Gateway name"
ER_Circuit_Name="Enter your ER Circuit name"


#--------------------------------------------------------------------------------------
#My own variables
az account set --subscription "viresent New AIRS"

#- SA North List Learned Routes -------------------------------------------------------------------------------------
RG="ER-LTSA-RG"
GateWayName="ER-GateWay-SA-North-Standard"
ER_Circuit_Name="ER-LIT-SA-North"
az network vnet-gateway list-learned-routes --resource-group "$RG" --name "$GateWayName" -o table
az network express-route show --resource-group "$RG" --name "$ER_Circuit_Name" -o table

#- SA West List Learned Routes -------------------------------------------------------------------------------------
RG="SA-West-rg"
GateWayName="ER-GateWay-SA-West-Standard"
ER_Circuit_Name="ER-LTSA-SA-West"
az network vnet-gateway list-learned-routes --resource-group "$RG" --name "$GateWayName" -o table
az network express-route show --resource-group "$RG" --name "$ER_Circuit_Name" -o table

#--------------------------------------------------------------------------------------
RG="ZA-East-vDC"
GateWayName="ZA-East-vDC-VPN-GW"
az network vnet-gateway list-learned-routes --resource-group "$RG" --name "$GateWayName" -o table

#PoC Gateways
#--------------------------------------------------------------------------------------
RG="AVS-ZA-North"
GateWayName="/subscriptions/0cfd0d2a-2b38-4c93-ba14-cf79185bc683/resourceGroups/AVS-ZA-North/providers/Microsoft.Network/vpnGateways/baa078faa98242289ff0921db75aa366-southafricanorth-gw"
# If GateWayName is a resource ID, pass only its name for this command.
az network vnet-gateway list-learned-routes --resource-group "$RG" --name "$GateWayName" -o table

#- Get Effective Routes -------------------------------------------------------------------------------------
az network nic show-effective-route-table --resource-group AVS-ZA-North --name vm-1-west-us-2765 -o table

#- Example
az network nic show-effective-route-table --resource-group ">>>Resource-Group-Name<<<" --name ">>>VM-NIC-Name<<<" -o table


==================================================================================================
#ExpressRoute Circuit Status and show S-Tag
==================================================================================================
RG="ER-LTSA-RG"
GateWayName="ER-GateWay-SA-North-Standard"
ER_Circuit_Name="ER-LIT-SA-North"
az network express-route show --resource-group "$RG" --name "$ER_Circuit_Name" -o jsonc


=============================================================================================================================================================================
#ER Circuit verification , get all details of ER Links + MSEE Port details
=============================================================================================================================================================================
RG="ER-LTSA-RG"
GateWayName="ER-GateWay-SA-North-Standard"
ER_Circuit_Name="ER-LIT-SA-North"
az network express-route peering show --resource-group "$RG" --circuit-name "$ER_Circuit_Name" --name AzurePrivatePeering -o table


=============================================================================================================================================================================
#ER Circuit Private Peering Enable/Disable
=============================================================================================================================================================================
# Enable:
az network express-route peering update --resource-group "ER-LTSA-RG" --circuit-name "ER-LIT-SA-North" --name AzurePrivatePeering --set state=Enabled -o table

# Disable:
az network express-route peering update --resource-group "ER-LTSA-RG" --circuit-name "ER-LIT-SA-North" --name AzurePrivatePeering --set state=Disabled -o table



=======================================================================================================
#Run to see list and count Learned Routes
=======================================================================================================
az network vnet-gateway list-learned-routes --resource-group "$RG" --name "$GateWayName" -o table
az network vnet-gateway list-learned-routes --resource-group "$RG" --name "$GateWayName" --query "length(value)" -o tsv



=======================================================================================================192
#Run to see list and count Learned Routes and Sort by Network
=======================================================================================================
az network vnet-gateway list-learned-routes --resource-group "$RG" --name "$GateWayName" --query "sort_by(value,&network)" -o table
az network vnet-gateway list-learned-routes --resource-group "$RG" --name "$GateWayName" --query "length(value)" -o tsv



=======================================================================================================
#Run to count Learned Routes
=======================================================================================================
az network vnet-gateway list-learned-routes --resource-group "$RG" --name "$GateWayName" --query "length(value)" -o table



=======================================================================================================
#Run to get ER primary and Secondary links ARP table
=======================================================================================================
az network express-route list-arp-tables --resource-group "$RG" --name "$ER_Circuit_Name" --peering-name AzurePrivatePeering --path primary -o table
az network express-route list-arp-tables --resource-group "$RG" --name "$ER_Circuit_Name" --peering-name AzurePrivatePeering --path secondary -o table



=======================================================================================================
#Filter an IP prefix
az network vnet-gateway list-learned-routes --resource-group "$RG" --name "$GateWayName" --query "value[?contains(network, '192.168')]" -o table



=======================================================================================================
#Filter a BGP ASN = 65522 (OnPrem VMWare)
=======================================================================================================
az network vnet-gateway list-learned-routes --resource-group "$RG" --name "$GateWayName" --query "value[?contains(asPath, '65522')]" -o table



==============================================================================================================================================================================
#Export Learned Routes to CSV in C:\ER-Learned-Routes\ER-Learned-Routes.csv and Count and List all Learned Routes
==============================================================================================================================================================================
OUTPUT_CSV="./ER-Learned-Routes.csv"
echo "Network,NextHop,AsPath,Weight" > "$OUTPUT_CSV"
az network vnet-gateway list-learned-routes --resource-group "$RG" --name "$GateWayName" --query "sort_by(value,&network)[].{Network:network,NextHop:nextHop,AsPath:asPath,Weight:weight}" -o tsv \
  | awk -F'\t' 'BEGIN{OFS=","} {print $1,$2,$3,$4}' >> "$OUTPUT_CSV"
cat "$OUTPUT_CSV"
az network vnet-gateway list-learned-routes --resource-group "$RG" --name "$GateWayName" --query "length(value)" -o tsv


==============================================================================================================================================================================
# ARP table for Azure private peering - Primary + Secondary paths
==============================================================================================================================================================================
# ARP table for Azure private peering - Primary path
az network express-route list-arp-tables --resource-group "$RG" --name "$ER_Circuit_Name" --peering-name AzurePrivatePeering --path primary -o table

# ARP table for Azure private peering - Secondary path
az network express-route list-arp-tables --resource-group "$RG" --name "$ER_Circuit_Name" --peering-name AzurePrivatePeering --path secondary -o table



===================================================================================================================================================================================================
az network vnet-gateway list-learned-routes --resource-group "$RG" --name "$GateWayName" --query "value[?network=='10.10.0.0/16'].{Network:network,NextHop:nextHop,AsPath:asPath,Weight:weight}" -o table

Output like this


Network      NextHop       AsPath      Weight
-------      -------       ------      ------
10.1.11.0/25 192.168.11.88 65020        32768
10.1.11.0/25 10.17.11.76   65020        32768
10.1.11.0/25 10.17.11.69   12076-65020  32769
10.1.11.0/25 10.17.11.69   12076-65020  32769
10.1.11.0/25 192.168.11.88 65020        32768
10.1.11.0/25 10.17.11.77   65020        32768
10.1.11.0/25 10.17.11.69   12076-65020  32769
10.1.11.0/25 10.17.11.69   12076-65020  32769


===================================================================================================================================================================================================
Reset ER Circuit::
===================================================================================================================================================================================================


# Connect to your Azure Subscription.
az login

#-------------------------------------------------------------------------------------------------------------------------------------
# If you have more than one subscription, get a list of your Azure subscriptions.
az account list -o table

#-------------------------------------------------------------------------------------------------------------------------------------
# Specify the subscription that you want to use.
az account set --subscription "Name of subscription"

az account set --subscription "viresent New AIRS"

# No direct Azure CLI equivalent of Set-AzExpressRouteCircuit refresh exists.
# Common operational workaround is to flap private peering:
az network express-route peering update --resource-group "ER-LTSA-RG" --circuit-name "ER-LIT-SA-North" --name AzurePrivatePeering --set state=Disabled -o none

az network express-route peering update --resource-group "ER-LTSA-RG" --circuit-name "ER-LIT-SA-North" --name AzurePrivatePeering --set state=Enabled -o none



===================================================================================================================================================================================================
Reset VPN Gateway ::
===================================================================================================================================================================================================
RG="ZA-East-vDC"
GateWayName="ZA-East-vDC-VPN-GW"

az network vnet-gateway reset --resource-group "$RG" --name "$GateWayName" -o jsonc
