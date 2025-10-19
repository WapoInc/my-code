#!/bin/bash
# Usage: ./2_VNG-User-set.ps1

$RgName = Read-Host -Prompt 'Input your Resource Group'

$gw1pip1 = New-AzPublicIpAddress -Name "TS-VpnGw5AZ-PublicIP-1" -ResourceGroupName $RgName -Location "northeurope" -AllocationMethod Static -Sku Standard
$gw1pip2 = New-AzPublicIpAddress -Name "TS-VpnGw5AZ-PublicIP-2" -ResourceGroupName $RgName -Location "northeurope" -AllocationMethod Static -Sku Standard
$gw4pip1 = New-AzPublicIpAddress -Name "TS-ERGatewayIP" -ResourceGroupName $RgName -Location "northeurope" -AllocationMethod Dynamic

$vnet1 = Get-AzVirtualNetwork -Name "VNET-T-1" -ResourceGroupName $RgName
$subnet1 = Get-AzVirtualNetworkSubnetConfig -Name "GatewaySubnet" -VirtualNetwork $vnet1


$gw1ipconf1 = New-AzVirtualNetworkGatewayIpConfig -Name "gw1ipconf1" -Subnet $subnet1 -PublicIpAddress $gw1pip1
$gw1ipconf2 = New-AzVirtualNetworkGatewayIpConfig -Name "gw1ipconf2" -Subnet $subnet1 -PublicIpAddress $gw1pip2
$gw4ipconf6 = New-AzVirtualNetworkGatewayIpConfig -Name "ERGatewayIpConfig" -SubnetId $subnet1.Id -PublicIpAddressId $gw4pip1.Id

New-AzVirtualNetworkGateway -Name "TS-VpnGw5AZ" -ResourceGroupName $RgName -Location "northeurope" -IpConfigurations $gw1ipconf1,$gw1ipconf2 -GatewayType Vpn -VpnType RouteBased -GatewaySku VpnGw5AZ -Asn "65616" -VpnGatewayGeneration "Generation2" -EnableActiveActiveFeature -EnableBgp 1 -EnablePrivateIpAddress
New-AzVirtualNetworkGateway -Name "TS-ERGateway" -ResourceGroupName $RgName -Location "northeurope" -IpConfigurations $gw4ipconf6 -GatewayType "ExpressRoute" -GatewaySku Standard
