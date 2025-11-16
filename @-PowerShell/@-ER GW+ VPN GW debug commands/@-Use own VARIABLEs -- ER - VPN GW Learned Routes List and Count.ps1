
# Login to Azure
Connect-AzAccount -Tenant MngEnv461963.onmicrosoft.com
Connect-AzAccount -SubscriptionName "viresent New AIRS"
Select-AzSubscription -SubscriptionName "viresent-New-AIRS" -Tenant MngEnv461963.onmicrosoft.com

Get-AzSubscription
Select-AzSubscription -SubscriptionName "Enter your Sub name"


#--------------------------------------------------------------------------------------
#Enter your variables
$RG = "Enter your Resource Group name"
$GateWayName = "Enter your ER or VPN Gateway name" 
$ER_Circuit_Name = "Enter your ER Circuit name"


#--------------------------------------------------------------------------------------
#My own variables
Select-AzSubscription -SubscriptionName "viresent New AIRS" -Tenant MngEnv461963.onmicrosoft.com

#- SA North -------------------------------------------------------------------------------------
$GateWayName = "2-ZAN-ER-GW-Migration-Test-for-Shoppies" 
$RG = "za-east-vdc"

$RG = "ER-LTSA-RG"
$GateWayName = "ER-GateWay-SA-North-Standard" 
$ER_Circuit_Name = "ER-LIT-SA-North"
Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayname $GateWayName
Get-AzExpressRouteCircuit -ResourceGroupName $RG -Name $ER_Circuit_Name



#- SA West -------------------------------------------------------------------------------------
$RG = "SA-West-RG"
$GateWayName = "ER-GateWay-SA-West-Standard"
$ER_Circuit_Name = "ER-LTSA-SA-West"
Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayname $GateWayName
Get-AzExpressRouteCircuit -ResourceGroupName $RG -Name $ER_Circuit_Name


#--------------------------------------------------------------------------------------
$RG = "ZA-East-vDC"
$GateWayName = "ZA-East-vDC-VPN-GW" 
Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayname $GateWayName


#PoC Gateways
#--------------------------------------------------------------------------------------
$RG = "AVS-ZA-North"
$GateWayName = "/subscriptions/0cfd0d2a-2b38-4c93-ba14-cf79185bc683/resourceGroups/AVS-ZA-North/providers/Microsoft.Network/vpnGateways/baa078faa98242289ff0921db75aa366-southafricanorth-gw"
Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayname $GateWayName

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
Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayname $GateWayName
Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayname $GateWayName | ForEach-Object Network | Measure-Object | Select-Object Count




=======================================================================================================
#Run to see list and count Learned Routes and Sort by Network
=======================================================================================================
Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayname $GateWayName |Sort-Object Network
Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayname $GateWayName | ForEach-Object Network | Measure-Object | Select-Object Count




=======================================================================================================
#Run to count Learned Routes 
=======================================================================================================
Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayname $GateWayName | Measure-Object | Select-Object Count



=======================================================================================================
#Run to get ER primary and Secondary links ARP table 
=======================================================================================================
AzExpressRouteCircuitARPTable -ResourceGroupName $RG -ExpressRouteCircuitName $ER_Circuit_Name -PeeringType AzurePrivatePeering -DevicePath Primary
AzExpressRouteCircuitARPTable -ResourceGroupName $RG -ExpressRouteCircuitName $ER_Circuit_Name -PeeringType AzurePrivatePeering -DevicePath Secondary



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



===================================================================================================================================================================================================
Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayName $GateWayName | where {$_.Network -eq "10.10.0.0/16"} | select Network, NextHop, AsPath, Weight

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
Connect-AzAccount
 
#-------------------------------------------------------------------------------------------------------------------------------------
# If you have more than one subscription, get a list of your Azure subscriptions.
Get-AzSubscription
 
#-------------------------------------------------------------------------------------------------------------------------------------
# Specify the subscription that you want to use.
Select-AzSubscription -SubscriptionName "Name of subscription"

Select-AzSubscription -SubscriptionName "viresent New AIRS" -Tenant MngEnv461963.onmicrosoft.com


$ckt = Get-AzExpressRouteCircuit -Name "ER-LIT-SA-North" -ResourceGroupName "ER-LTSA-RG"
Set-AzExpressRouteCircuit -ExpressRouteCircuit $ckt



===================================================================================================================================================================================================
Reset VPN Gateway ::
===================================================================================================================================================================================================
$RG = "ZA-East-vDC"
$GateWayName = "ZA-East-vDC-VPN-GW"


$Gateway = Get-AzVirtualNetworkGateway -ResourceGroupName $RG -Name $GateWayName
Set-AzVirtualNetworkGateway -VirtualNetworkGateway $Gateway



