# Get-AzVirtualNetworkGatewayBgpPeerStatus

Connect-AzAccount
Get-AzSubscription
Select-AzSubscription -SubscriptionName "viresent - AIRS"

$RG = "ER-LTSA-RG"
$CircuitName = "ER-LTSA-SA-North"
$GateWayName = "LTSA-ER-GateWay-SA-North"


Get-AzVirtualNetworkGatewayBgpPeerStatus -ResourceGroupName $RG -VirtualNetworkGatewayName $GateWayName



