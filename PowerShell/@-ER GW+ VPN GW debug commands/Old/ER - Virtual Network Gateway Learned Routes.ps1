# Get-AzVirtualNetworkGatewayLearnedRoute





Connect-AzAccount

Get-AzSubscription

Select-AzSubscription -SubscriptionName "@viresent - AIRS"

Select-AzSubscription -SubscriptionName "Dele - Microsoft Azure Internal Consumption"

#ZA-East-vDC VPN GateWay 
$RG = "ZA-East-vDC"
$GateWayName = "VPN-GW-ZA-East-vDC"


#LTSA
#VPN GateWay // LTSA
$RG = "ER-LTSA-RG"
$GateWayName = "LTSA-VPN-GateWay-SA-North"

#ER GateWay // Az-Hub-ergw
$RG = "vmr-ARS-PoC-DanielM2"
$CircuitName = "ER-LTSA-SA-North"
$GateWayName = "Az-Hub-ergw"

#ER GateWay // LTSA
$RG = "ER-LTSA-RG"
$CircuitName = "ER-LTSA-SA-North"
$GateWayName = "LTSA-ER-GateWay-SA-North"

#ER GateWay // Dele ARS-PoC
$RG = "vmr-ARS-PoC"
$CircuitName = "ER-LTSA-SA-North"
$GateWayName = "ER-GW-ARS-PoC"

#ER GateWay // Visual Studio Subscription
$RG = "ER-Circuit-Auth-PoC"
$GateWayName = "ER-GW-Visual-Studio-Sub"

#StatsSA VPN GW 
$RG = "StatsSA-PoC"
$GateWayName = "Site2sideVNG"


#Run for all 
Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayname $GateWayName

