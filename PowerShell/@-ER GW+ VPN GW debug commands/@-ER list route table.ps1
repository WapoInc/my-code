
# Login to Azure
Connect-AzAccount -Tenant MngEnv461963.onmicrosoft.com
Connect-AzAccount -SubscriptionName "viresent New AIRS"
Select-AzSubscription -SubscriptionName "viresent-New-AIRS" -Tenant MngEnv461963.onmicrosoft.com

Get-AzSubscription
Select-AzSubscription -SubscriptionName "Enter your Sub name"


#- SA North -------------------------------------------------------------------------------------
$GatewayResourceGroup = "southafricanorth-region"
$CircuitResourceGroup = "ER-LTSA-rg"
$GateWayName = "ER-GateWay-southafricanorth-Standard" 
$ER_Circuit_Name = "ER-LIT-ZAN"


Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $GatewayResourceGroup -VirtualNetworkGatewayname $GateWayName
Get-AzExpressRouteCircuit -ResourceGroupName $CircuitResourceGroup -Name $ER_Circuit_Name

#- Get Effective Routes -------------------------------------------------------------------------------------

az network nic show-effective-route-table --resource-group AVS-ZA-North --name vm-1-west-us-2765 -o table
#- Example
az network nic show-effective-route-table --resource-group >>>Resource-Group-Name<<< --name >>>VM-NIC-Name<<< -o table
==================================================================================================
#ExpressRoute Circuit Status and show S-Tag
==================================================================================================
Get-AzExpressRouteCircuit -ResourceGroupName $RG -Name $ER_Circuit_Name

=============================================================================================================================================================================
#ER Circuit verification
=============================================================================================================================================================================
$ckt = Get-AzExpressRouteCircuit -ResourceGroupName $RG -Name $ER_Circuit_Name
Get-AzExpressRouteCircuitPeeringConfig -Name "AzurePrivatePeering" -ExpressRouteCircuit $ckt


=============================================================================================================================================================================
#ER Circuit Private Peering Enable/Disable
=============================================================================================================================================================================
Enable:
$ckt = Get-AzExpressRouteCircuit -Name "ER-LIT-SA-North" -ResourceGroupName "ER-LTSA-RG"
$ckt.Peerings[0].State = "Enabled"
Set-AzExpressRouteCircuit -ExpressRouteCircuit $ckt

Disable:
$ckt = Get-AzExpressRouteCircuit -Name "ER-LIT-SA-North" -ResourceGroupName "ER-LTSA-RG"
$ckt.Peerings[0].State = "Disabled"
Set-AzExpressRouteCircuit -ExpressRouteCircuit $ckt



=======================================================================================================
#Run to see list and count Learned Routes
=======================================================================================================
Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $GatewayResourceGroup -VirtualNetworkGatewayname $GateWayName
Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $GatewayResourceGroup -VirtualNetworkGatewayname $GateWayName | ForEach-Object Network | Measure-Object | Select-Object Count

=======================================================================================================
#Run to see list and count Learned Routes and Sort by Network
=======================================================================================================
Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $GatewayResourceGroup -VirtualNetworkGatewayName $GateWayName | Sort-Object Network
Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $GatewayResourceGroup -VirtualNetworkGatewayName $GateWayName | ForEach-Object Network | Measure-Object | Select-Object Count


=======================================================================================================
#Run to count Learned Routes 
=======================================================================================================
Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayname $GateWayName | Measure-Object | Select-Object Count

=======================================================================================================
#Run to get ER primary and Secondary links ARP table 
=======================================================================================================
Get-AzExpressRouteCircuitARPTable -ResourceGroupName $CircuitResourceGroup -ExpressRouteCircuitName $ER_Circuit_Name -PeeringType AzurePrivatePeering -DevicePath Primary
Get-AzExpressRouteCircuitARPTable -ResourceGroupName $CircuitResourceGroup -ExpressRouteCircuitName $ER_Circuit_Name -PeeringType AzurePrivatePeering -DevicePath Secondary


=======================================================================================================  
#Filter an IP prefix
Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayname $GateWayName | Where-Object -Property Network -Match 10.111.1.0




=======================================================================================================
#Filter a BGP ASN = 65522 (OnPrem VMWare)
=======================================================================================================
Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayname $GateWayName | Where-Object -Property AsPath -Match 65522




==============================================================================================================================================================================
#Export Learned Routes to CSV in C:\ER-Learned-Routes\ER-Learned-Routes.csv and Count and List all Learned Routes 
==============================================================================================================================================================================
Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayname $GateWayName |Sort-Object Network |Export-Csv 'C:\ER-Learned-Routes\ER-Learned-Routes.csv'   -NoTypeInformation 
Get-Content -Path 'C:\ER-Learned-Routes\ER-Learned-Routes.csv'
Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayname $GateWayName | ForEach-Object Network | Measure-Object | Select-Object Count


==============================================================================================================================================================================
# ARP table for Azure private peering - Primary + Secondary paths               
==============================================================================================================================================================================
# ARP table for Azure private peering - Primary path
Get-AzExpressRouteCircuitARPTable -ResourceGroupName $RG -ExpressRouteCircuitName $ER_Circuit_Name -PeeringType AzurePrivatePeering -DevicePath Primary

# ARP table for Azure private peering - Secondary path
Get-AzExpressRouteCircuitARPTable -ResourceGroupName $RG -ExpressRouteCircuitName $ER_Circuit_Name -PeeringType AzurePrivatePeering -DevicePath Secondary


