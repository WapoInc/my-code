# Get-AzVirtualNetworkGatewayLearnedRoute





Connect-AzAccount
Get-AzSubscription
Select-AzSubscription -SubscriptionName "@viresent - AIRS"


#VPN GateWay // Az-Stratus
$RG = "Az-Stratus-rg"
$GateWayName = "VPN-GW-Az-Stratus"


#LTSA
#VPN GateWay // LTSA
$RG = "ER-LTSA-RG"
$GateWayName = "LTSA-VPN-GateWay-SA-North"

#ER GateWay // LTSA
$RG = "ER-LTSA-RG"
$CircuitName = "LTSA-ER-GateWay-SA-North"
$GateWayName = "LTSA-ER-GateWay-SA-North"


#ER GateWay // Visual Studio Subscription
$RG = "ER-Circuit-Auth-PoC"
$GateWayName = "ER-GW-Visual-Studio-Sub"


#Run for all 
Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayname $GateWayName

