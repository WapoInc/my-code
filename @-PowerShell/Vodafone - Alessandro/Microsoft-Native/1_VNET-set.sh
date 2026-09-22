#!/bin/bash
# Usage: bash 1_VNET-set.sh <resource group>

RgName=$1

#VNET User creation
az network vnet create \
-g $RgName \
-n VNET-User-1 \
--address-prefixes 11.101.4.0/26 \
--subnet-name subnetU1-1 \
--subnet-prefixes 11.101.4.0/27

az network vnet subnet create \
-g $RgName \
--vnet-name VNET-User-1 \
--name GatewaySubnet \
--address-prefixes 11.101.4.32/27

#VNET User creation
az network vnet create \
-g $RgName \
-n VNET-User-2 \
--address-prefixes 11.101.4.64/26 \
--subnet-name subnetU2-1 \
--subnet-prefixes 11.101.4.64/27

az network vnet subnet create \
-g $RgName \
--vnet-name VNET-User-2 \
--name GatewaySubnet \
--address-prefixes 11.101.4.96/27

#VNET User creation
az network vnet create \
-g $RgName \
-n VNET-T-1 \
--address-prefixes 11.101.3.128/26 \
--subnet-name GatewaySubnet \
--subnet-prefixes 11.101.3.160/27


#Get Subnet created
az network vnet subnet list \
    --resource-group $RgName \
    --vnet-name VNET-User-1 \
    --output table

#Get Subnet created
az network vnet subnet list \
    --resource-group $RgName \
    --vnet-name VNET-User-2 \
    --output table

#Get Subnet created
az network vnet subnet list \
    --resource-group $RgName \
    --vnet-name VNET-T-1 \
    --output table


az vm create \
--name VM-User1 \
--resource-group $RgName \
--image UbuntuLTS \
--size Standard_DS1_v2 \
--vnet-name VNET-User-1 \
--subnet subnetU1-1 \
--admin-username azureuser \
--admin-password azureuserSoloi35!

az vm create \
--name VM-User2 \
--resource-group $RgName \
--image UbuntuLTS \
--size Standard_DS1_v2 \
--vnet-name VNET-User-2 \
--subnet subnetU2-1 \
--admin-username azureuser \
--admin-password azureuserSoloi35!


watch -d -n 5 "az vm list \
    --resource-group $RgName \
    --show-details \
    --query '[*].{Name:name, ProvisioningState:provisioningState, PowerState:powerState}' \
    --output table"

#get the name of the NVA network interface
NICID=$(az vm nic list \
    --resource-group $RgName \
    --vm-name VM-User1 \
    --query "[].{id:id}" --output tsv)

echo $NICID

NICNAME=$(az vm nic show \
    --resource-group $RgName \
    --vm-name VM-User1 \
    --nic $NICID \
    --query "{name:name}" --output tsv)

echo $NICNAME

#enable IP forwarding for the network interface
az network nic update --name $NICNAME \
    --resource-group $RgName \
    --ip-forwarding true

#get the name of the NVA network interface
NICID=$(az vm nic list \
    --resource-group $RgName \
    --vm-name VM-User2 \
    --query "[].{id:id}" --output tsv)

echo $NICID

NICNAME=$(az vm nic show \
    --resource-group $RgName \
    --vm-name VM-User2 \
    --nic $NICID \
    --query "{name:name}" --output tsv)

echo $NICNAME

#enable IP forwarding for the network interface
az network nic update --name $NICNAME \
--resource-group $RgName \
--ip-forwarding true

#Get IP
PUBLICIP="$(az vm list-ip-addresses \
    --resource-group $RgName \
    --name VM-User1 \
    --query "[].virtualMachine.network.publicIpAddresses[*].ipAddress" \
    --output tsv)"

echo ______________
echo VM_with_public_ip:
echo $PUBLICIP

PRIVATEIP="$(az vm list-ip-addresses \
    --resource-group $RgName \
    --name VM-User1 \
    --query "[].virtualMachine.network.privateIpAddresses" \
    --output tsv)"

echo ______________
echo VM_with_private_ip:
echo $PRIVATEIP

#Get IP
PUBLICIP="$(az vm list-ip-addresses \
    --resource-group $RgName \
    --name VM-User2 \
    --query "[].virtualMachine.network.publicIpAddresses[*].ipAddress" \
    --output tsv)"

echo ______________
echo VM_with_public_ip:
echo $PUBLICIP

PRIVATEIP="$(az vm list-ip-addresses \
    --resource-group $RgName \
    --name VM-User2 \
    --query "[].virtualMachine.network.privateIpAddresses" \
    --output tsv)"

echo ______________
echo VM_with_private_ip:
echo $PRIVATEIP
