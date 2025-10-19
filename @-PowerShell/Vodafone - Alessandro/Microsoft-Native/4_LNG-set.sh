#!/bin/bash
# Usage: bash 4_LNG-set.sh <resource group>

RgName=$1
SHAREDKEY="gDcCl0udAw5_1725_Native"

#Create LNG-HQ-Network local network gateway
az network local-gateway create \
    --resource-group $RgName \
    --gateway-ip-address 11.100.19.3 \
    --name LNG-IE1LABCGW01-1 \
    --asn 64643 \
    --bgp-peering-address 11.101.2.160

#VPN creation
az network vpn-connection create \
    --resource-group $RgName \
    --name VNET-T-1-To-IE1LABCGW01-1 \
    --vnet-gateway1 TS-VpnGw5AZ \
    --shared-key $SHAREDKEY \
    --local-gateway2 LNG-IE1LABCGW01-1


#Create LNG-HQ-Network local network gateway
az network local-gateway create \
    --resource-group $RgName \
    --gateway-ip-address 11.100.19.4 \
    --name LNG-IE1LABCGW01-2 \
    --asn 64643 \
    --bgp-peering-address 11.101.2.161

#VPN creation
az network vpn-connection create \
    --resource-group $RgName1 \
    --name VNET-T-1-To-IE1LABCGW01-2 \
    --vnet-gateway1 TS-VpnGw5AZ \
    --shared-key $SHAREDKEY \
    --local-gateway2 LNG-IE1LABCGW01-2
