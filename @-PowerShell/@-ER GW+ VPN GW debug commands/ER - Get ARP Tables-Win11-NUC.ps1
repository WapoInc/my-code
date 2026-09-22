# Get-AzExpressRouteCircuitARPTable

Connect-AzAccount
Get-AzSubscription


Select-AzSubscription -SubscriptionName "@viresent - AIRS"



$RG = "ER-LTSA-RG"
$CircuitName = "ER-LTSA-SA-North"

      
    
# ARP table for Azure private peering - Primary path
Get-AzExpressRouteCircuitARPTable -ResourceGroupName $RG -ExpressRouteCircuitName $CircuitName -PeeringType AzurePrivatePeering -DevicePath Primary

# ARP table for Azure private peering - Secondary path
Get-AzExpressRouteCircuitARPTable -ResourceGroupName $RG -ExpressRouteCircuitName $CircuitName -PeeringType AzurePrivatePeering -DevicePath Secondary

