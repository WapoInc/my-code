#!/bin/bash
# Usage: ./5_PrivateIP-set.ps1

$RgName = Read-Host -Prompt 'Input your Resource Group'

$Connection1 = get-AzVirtualNetworkGatewayConnection -Name "VNET-T-1-To-IE1LABCGW01-1" -ResourceGroupName $RgName
$Connection2 = get-AzVirtualNetworkGatewayConnection -Name "VNET-T-1-To-IE1LABCGW01-2" -ResourceGroupName $RgName

Set-AzVirtualNetworkGatewayConnection -VirtualNetworkGatewayConnection $Connection1 -UseLocalAzureIpAddress $true -EnableBgp $true
Set-AzVirtualNetworkGatewayConnection -VirtualNetworkGatewayConnection $Connection2 -UseLocalAzureIpAddress $true -EnableBgp $true
