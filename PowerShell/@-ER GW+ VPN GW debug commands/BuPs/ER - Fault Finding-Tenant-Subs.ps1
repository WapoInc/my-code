
Connect-AzAccount
Get-AzSubscription


=AIRS Sub=======================================================================================================================
Select-AzSubscription -TenantId "5cba78fe-cc40-479a-9ee1-255423641bc9" -Subscription "0cfd0d2a-2b38-4c93-ba14-cf79185bc683"
Select-AzSubscription -SubscriptionName "viresent-New-AIRS"
================================================================================================
=Avis Tenant and Subs=======================================================================================================================
Tenant ID:76c0ec88-9190-4ef0-99ad-0be5680e8c5d
Zeda AVS SDDC :9a109088-126c-4893-8f77-d344e36c99b5
Zeda Connectivity Hub :fb09e4e3-0e35-4f27-80cd-5a967412b575
===================================================================================================================================
Select-AzSubscription -TenantId "76c0ec88-9190-4ef0-99ad-0be5680e8c5d" -Subscription "fb09e4e3-0e35-4f27-80cd-5a967412b575"
Set-AzContext -Subscription "fb09e4e3-0e35-4f27-80cd-5a967412b575"
Select-AzSubscription -SubscriptionName "Zeda Connectivity Hub"
Select-AzSubscription -SubscriptionName "Zeda AVS SDDC"
=AVIS======================================================================================================
$RG = "Zeda-Connectivity-Hub"
$CircuitName = "Zeda-ER-ZA-North"   
$GateWayName = "er-gw"
==========================================================================================================
=AIRS===========================================================================================================
Select-AzSubscription -SubscriptionName "viresent-New-AIRS"
=AIRS==========================================================================================================
$RG = "ER-LTSA-RG"
$CircuitName = "ER-LIT-SA-North"
$GateWayName = "ER-GateWay-SA-North_migrated"
#---------------------------------------------------------------------------------------------------------------
$RG = "ER-LTSA-RG"
$CircuitName = "ER-LTSA-SA-West"
$GateWayName = "ER-GateWay-SA-North_migrated"
================================================================================================================
#ER circuit info:
$ckt = Get-AzExpressRouteCircuit -Name $CircuitName -ResourceGroupName $RG
Get-AzExpressRouteCircuitPeeringConfig -Name "AzurePrivatePeering" -ExpressRouteCircuit $ckt
==================================================================================================================
# ARP table for Azure private peering - Primary path  //  # ARP table for Azure private peering - Secondary path
Get-AzExpressRouteCircuitARPTable -ResourceGroupName $RG -ExpressRouteCircuitName $CircuitName -PeeringType AzurePrivatePeering -DevicePath Primary
Get-AzExpressRouteCircuitARPTable -ResourceGroupName $RG -ExpressRouteCircuitName $CircuitName -PeeringType AzurePrivatePeering -DevicePath Secondary
================================================================================================================
#Run to see list of Learned Routes
Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayname $GateWayName
==================================================================================================================
#Run to see list of Learned Routes and Sort by Network
Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayname $GateWayName | Sort-Object Network
===================================================================================================================
#Run to count Learned Routes 
=============================================================================================================================================
Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayname $GateWayName | Measure-Object | Select-Object Count
=======================================================================================================  
#Filter an IP prefix - 10.198.248.0/26  -or-  10.198.248.*
Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayname $GateWayName | Where-Object -Property Network -Match 10.198.25*.*
Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayname $GateWayName | Where-Object -Property Network -Match 10.97.*.* | Sort-Object Network