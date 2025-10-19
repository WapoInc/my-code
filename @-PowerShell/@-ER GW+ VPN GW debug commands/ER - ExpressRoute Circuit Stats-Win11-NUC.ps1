# Get-AzExpressRouteCircuitStat

Connect-AzAccount
Get-AzSubscription
Select-AzSubscription -SubscriptionName "@viresent - New AIRS-ME-MngEnv461963"

$RG = "ER-LTSA-RG"
$CircuitName = "ER-LTSA-SA-North"




Get-AzExpressRouteCircuitStat -ResourceGroupName $RG -ExpressRouteCircuitName $CircuitName -PeeringType 'AzurePrivatePeering'

