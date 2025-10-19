az login
Connect-AzAccount
Connect-AzAccount -TenantId "5cba78fe-cc40-479a-9ee1-255423641bc9" -Subscription "0cfd0d2a-2b38-4c93-ba14-cf79185bc683"
Get-AzSubscription


Connect-AzAccount -Tenant "5cba78fe-cc40-479a-9ee1-255423641bc9"

=AIRS Sub=======================================================================================================================
Select-AzSubscription -TenantId "5cba78fe-cc40-479a-9ee1-255423641bc9" -Subscription "0cfd0d2a-2b38-4c93-ba14-cf79185bc683"
Select-AzSubscription -SubscriptionName "viresent-New-AIRS"

=AIRS===========================================================================================================
Select-AzSubscription -SubscriptionName "viresent-New-AIRS"

=AIRS==========================================================================================================
$RG = "ER-LTSA-RG"
$CircuitName = "ER-LIT-SA-North"
$GateWayName = "ER-GateWay-SA-North-Standard"
#---------------------------------------------------------------------------------------------------------------
$RG = "ER-LTSA-RG"
$CircuitName = "ER-LTSA-SA-West"
$GateWayName = "ER-GateWay-SA-North"
================================================================================================================
#ER circuit info:
$ckt = Get-AzExpressRouteCircuit -Name $CircuitName -ResourceGroupName $RG
Get-AzExpressRouteCircuitPeeringConfig -Name "AzurePrivatePeering" -ExpressRouteCircuit $ckt
==================================================================================================
#ExpressRoute Circuit Status and show S-Tag
Get-AzExpressRouteCircuit -ResourceGroupName $RG -Name $CircuitName
========================================================================================================================================================
# ARP table for Azure private peering - Primary path  //  # ARP table for Azure private peering - Secondary path
Get-AzExpressRouteCircuitARPTable -ResourceGroupName $RG -ExpressRouteCircuitName $CircuitName -PeeringType AzurePrivatePeering -DevicePath Primary
Get-AzExpressRouteCircuitARPTable -ResourceGroupName $RG -ExpressRouteCircuitName $CircuitName -PeeringType AzurePrivatePeering -DevicePath Secondary
=========================================================================================================================================================
#Run to see list of Learned Routes
Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayname $GateWayName
=========================================================================================================================================================
#Run to see list of Learned Routes and SORT by Network
Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayname $GateWayName | Sort-Object Network 
Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayname $GateWayName | Measure-Object | Select-Object Count

Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayname $GateWayName | Sort-Object Network | Where-Object NextHop -Match 10.198.255.4
Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayname $GateWayName | Sort-Object Network | Where-Object NextHop -Match 10.198.255.5
Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayname $GateWayName | Measure-Object | Select-Object Count

Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayname $GateWayName | Sort-Object Network | Where-Object LocalAddress -Match 10.198.255.12
Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayname $GateWayName | Sort-Object Network | Where-Object LocalAddress -Match 10.198.255.13
Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayname $GateWayName | Measure-Object | Select-Object Count

================================================================================================================================================
#Run to count Learned Routes 
================================================================================================================================================
Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayname $GateWayName | Measure-Object | Select-Object Count
===================================================================================================================================================
#Filter an IP prefix - 10.198.248.0/26  -or-  10.198.248.*
Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayname $GateWayName | Where-Object -Property Network -Match 172.198.250*.*
===============================================================================================================================================================
# get BGP status
Get-AzVirtualNetworkGatewayBgpPeerStatus -ResourceGroupName $RG -VirtualNetworkGatewayName $GateWayName
===============================================================================================================================================================


# Filter by specific CIDR range

Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayname $GateWayName | Where-Object -Property Network -Match 172.26.0.* | Sort-Object Network
Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayname $GateWayName | Where-Object -Property Network -Match 172.* | Sort-Object Network
Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayname $GateWayName | Where-Object -Property Network -Match 10.98.254.* | Sort-Object Network
Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayname $GateWayName | Where-Object -Property Network -Match 10.10.127.* | Sort-Object Network
Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayname $GateWayName | Where-Object -Property Network -Match 10.97.202.*| Sort-Object Network
Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayname $GateWayName | Where-Object -Property Network -Match 10.98.1.* | Sort-Object Network
Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayname $GateWayName | Where-Object -Property Network -Match 10.98.*.* | Sort-Object Network



No seeing these CIDR listed

10.98.250.0/24
10.98.252.0/24
10.98.254.0/24
10.10.127.0/24
10.10.76.0/24
10.97.202.0/24
10.98.1.0/24.