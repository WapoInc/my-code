# Get-AzExpressRouteCircuitRouteTableSummary 

Connect-AzAccount
Get-AzSubscription
Select-AzSubscription -SubscriptionName "@viresent - AIRS"

$RG = "ER-LTSA-RG"
$CircuitName = "ER-LIT-SA-North"

$RG = "Shared_Services"
$CircuitName = "SITA_Internal"


Get-AzExpressRouteCircuitRouteTableSummary -ResourceGroupName $RG -ExpressRouteCircuitName $CircuitName -DevicePath 'Primary'-PeeringType AzurePrivatePeering



