
# Login to Azure
Connect-AzAccount
Get-AzSubscription
Select-AzSubscription -SubscriptionName "New-AIRS-viresent"



==================================================================================================
#ExpressRoute Circuit Status
==================================================================================================
$ER_Circuit_ER_LTSA_SA_North = "ER-LTSA-SA-North"
$RG = "ER-LTSA-RG"
Get-AzExpressRouteCircuit -ResourceGroupName $RG -Name $ER_Circuit_ER_LTSA_SA_North 
==================================================================================================
$ER_Circuit_ER_LTSA_SA_West = "ER-LTSA-SA-West"
$RG = "ER-LTSA-RG"
Get-AzExpressRouteCircuit -ResourceGroupName $RG -Name $ER_Circuit_ER_LTSA_SA_West 
==================================================================================================



=================================================================================================
#LTSA
==================================================================================================
#VPN GateWay // LTSA
==================================================================================================
$RG = "ER-LTSA-RG"
$GateWayName = "LTSA-VPN-GateWay-SA-North"
==================================================================================================
#ER GateWay // LTSA // SA North 
==================================================================================================
$RG = "ER-LTSA-RG"
$GateWayName = "ER-GateWay-SA-North"
==================================================================================================
#ER GateWay // LTSA // SA West 
==================================================================================================
$RG = "SA-West-rg"
$GateWayName = "ER-GateWay-SA-West"
==================================================================================================



==================================================================================================
#ZA-East-vDC
==================================================================================================
#$CircuitName = "LTSA-ER-GateWay-SA-North" 
$RG = "za-east-vdc"
$GateWayName = "ZA-East-vDC-VPN-GW"
==================================================================================================
#ER GateWay // ZA-East-vDC 
==================================================================================================
$RG = "za-east-vdc"
$GateWayName = "ER-GW-ZA-East-vDC"
==================================================================================================
#ER GateWay // vWAN Hub 
==================================================================================================
$GateWayName = "43eee246f789433b910511412e315f03-southafricanorth-er-gw"
==================================================================================================



=======================================================================================================
#Run to count Learned Routes 
=============================================================================================================================================
Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayname $GateWayName | Measure-Object | Select-Object Count
=============================================================================================================================================

=======================================================================================================
#Run to see list of Learned Routes
=======================================================================================================
Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayname $GateWayName
=======================================================================================================


=======================================================================================================
#Run to see list of Learned Routes and Sort by Network
============================================================================================================================
Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayname $GateWayName | Sort-Object Network
============================================================================================================================


=======================================================================================================
#Test new Pipe commands
=======================================================================================================  
#Filter an IP prefix
Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayname $GateWayName | Where-Object -Property Network -Match 172.32.1.0
=======================================================================================================
#Filter a BGP ASN
Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayname $GateWayName | Where-Object -Property AsPath -Match 65522
=======================================================================================================
#Count Filter list Networks Learned
Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayname $GateWayName | ForEach-Object Network | Measure-Object | Select-Object Count 
=======================================================================================================
#Run to see list of Learned Routes and Sort by Network
Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayname $GateWayName |Sort-Object Network
=======================================================================================================





==============================================================================================================================================================================
#Export to CSV - SA North
==============================================================================================================================================================================
$RG = "ER-LTSA-RG"
$GateWayName = "LTSA-ER-GateWay-SA-North"

Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayname $GateWayName | Export-Csv '.\OneDrive\@-PowerShell\ER - VPN Learned Routes\My-SA-North-Learned-Routes.csv'   -NoTypeInformation 
Get-Content -Path '.\OneDrive\@-PowerShell\ER - VPN Learned Routes\My-SA-North-Learned-Routes.csv'
Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayname $GateWayName | ForEach-Object Network | Measure-Object | Select-Object Count
==============================================================================================================================================================================
#Export to CSV - SA West
=============================================================================================================================================================================
$RG = "ER-LTSA-RG"
$GateWayName = "LTSA-ER-GateWay-SA-West"

Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayname $GateWayName | Export-Csv '.\OneDrive\@-PowerShell\ER - VPN Learned Routes\My-SA-West-Learned-Routes.csv'   -NoTypeInformation 
Get-Content -Path '.\OneDrive\@-PowerShell\ER - VPN Learned Routes\My-SA-West-Learned-Routes.csv'
Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayname $GateWayName | ForEach-Object Network | Measure-Object | Select-Object Count
=============================================================================================================================================================================





=============================================================================================================================================================================
#ER Circuit verification
=============================================================================================================================================================================
$RG = "ER-LTSA-RG"
$ER_Circuit = "ER-LTSA-SA-North"
$ER_Circuit = "ER-LTSA-SA-West"

$ckt = Get-AzExpressRouteCircuit -ResourceGroupName $RG -Name $ER_Circuit
Get-AzExpressRouteCircuitPeeringConfig -Name "AzurePrivatePeering" -ExpressRouteCircuit $ckt

