# Get-AzExpressRouteCircuitARPTable

Connect-AzAccount
Get-AzSubscription


Select-AzSubscription -SubscriptionName "Zeda Connectivity Hub"



$RG = "ER-LTSA-RG"
$CircuitName = "ER-LIT-SA-North"
$CircuitName = "ER-LTSA-SA-West"

$RG = "Zeda-Connectivity-Hub"
$CircuitName = "Zeda-ER-ZA-North"    
    
# ARP table for Azure private peering - Primary path
Get-AzExpressRouteCircuitARPTable -ResourceGroupName $RG -ExpressRouteCircuitName $CircuitName -PeeringType AzurePrivatePeering -DevicePath Primary

# ARP table for Azure private peering - Secondary path
Get-AzExpressRouteCircuitARPTable -ResourceGroupName $RG -ExpressRouteCircuitName $CircuitName -PeeringType AzurePrivatePeering -DevicePath Secondary

