
# Login to Azure
Connect-AzAccount
Get-AzSubscription
Select-AzSubscription -SubscriptionName "Enter your Sub name"

#Enter your variables

$RG = "Enter your Resource Group name"
$GateWayName = "Enter your ER or VPN Gateway name" 
$ER_Circuit_Name = "Enter your ER Circuit name"


#My own variables
Select-AzSubscription -SubscriptionName "@viresent - AIRS"
$RG = "ER-LTSA-RG"
$GateWayName = "LTSA-VPN-GateWay-SA-North" 
$ER_Circuit_Name = "ER-LTSA-SA-North"



==================================================================================================
#ExpressRoute Circuit Status and show S-Tag
==================================================================================================
Get-AzExpressRouteCircuit -ResourceGroupName $RG -Name $ER_Circuit_Name




=============================================================================================================================================================================
#ER Circuit verification
=============================================================================================================================================================================
$ckt = Get-AzExpressRouteCircuit -ResourceGroupName $RG -Name $ER_Circuit_Name
Get-AzExpressRouteCircuitPeeringConfig -Name "AzurePrivatePeering" -ExpressRouteCircuit $ckt




=======================================================================================================
#Run to count Learned Routes 
=======================================================================================================
Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayname $GateWayName | Measure-Object | Select-Object Count





=======================================================================================================
#Run to see list and count Learned Routes
=======================================================================================================
Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayname $GateWayName
Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayname $GateWayName | ForEach-Object Network | Measure-Object | Select-Object Count






=======================================================================================================
#Run to see list of Learned Routes and Sort by Network
=======================================================================================================
Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayname $GateWayName |Sort-Object Network






=======================================================================================================  
#Filter an IP prefix = 172.32.1.0
Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayname $GateWayName | Where-Object -Property Network -Match 172.32.1.0




=======================================================================================================
#Filter a BGP ASN = 65522
=======================================================================================================
Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayname $GateWayName | Where-Object -Property AsPath -Match 65522





=======================================================================================================
#Run to see list of Learned Routes and Sort by Network
=======================================================================================================
Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayname $GateWayName |Sort-Object Network




==============================================================================================================================================================================
#Export Learned Routes to CSV in C:\ER-Learned-Routes\ER-Learned-Routes.csv and Count and List all Learned Routes 
==============================================================================================================================================================================
Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayname $GateWayName | Export-Csv 'C:\ER-Learned-Routes\ER-Learned-Routes.csv'   -NoTypeInformation 
Get-Content -Path 'C:\ER-Learned-Routes\ER-Learned-Routes.csv'
Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayname $GateWayName | ForEach-Object Network | Measure-Object | Select-Object Count


