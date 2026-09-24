# Get-AzExpressRouteCircuitPeeringConfig 

Connect-AzAccount
Get-AzSubscription
Select-AzSubscription -SubscriptionName "@viresent - New AIRS-ME-MngEnv461963"


$RG = "ER-LTSA-RG"
$CircuitName = "ER-LIT-SA-North"


    
$ckt = Get-AzExpressRouteCircuit -Name $CircuitName -ResourceGroupName $RG
Get-AzExpressRouteCircuitPeeringConfig -Name "AzurePrivatePeering" -ExpressRouteCircuit $ckt

