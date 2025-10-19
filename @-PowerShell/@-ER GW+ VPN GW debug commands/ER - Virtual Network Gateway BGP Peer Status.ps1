# Get-AzVirtualNetworkGatewayBgpPeerStatus

Connect-AzAccount
Get-AzSubscription
Select-AzSubscription -SubscriptionName "viresent - AIRS"

$RG = "ER-LTSA-RG"
$CircuitName = "ER-LIT-SA-North"
$GateWayName = "ER-GateWay-SA-North_migrated"

$RG = "Shared_Services"
$CircuitName = "SITA_Internal"   
$GateWayName = "er-gw-za-north"

$RG = "Zeda-Connectivity-Hub"
$CircuitName = "Zeda-ER-ZA-North"   
$GateWayName = "er-gw"


Get-AzVirtualNetworkGatewayBgpPeerStatus -ResourceGroupName $RG -VirtualNetworkGatewayName $GateWayName



