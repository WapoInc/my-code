# Get-AzExpressRouteCircuitRouteTableSummary 

Connect-AzAccount
Get-AzSubscription
Select-AzSubscription -SubscriptionName "@viresent - AIRS"

$RG = "ER-LTSA-RG"
$CircuitName = "ER-LTSA-SA-North"


Get-AzExpressRouteCircuitRouteTableSummary -ResourceGroupName $RG -ExpressRouteCircuitName $CircuitName -DevicePath 'Primary'-PeeringType AzurePrivatePeering



