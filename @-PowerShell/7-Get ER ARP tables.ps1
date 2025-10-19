


# Required Variables
$RG = "ER-LTSA-RG"
$Name = "ER-LIT-SA-North"
$Name = "ER-LTSA-SA-West"

# Select-AzSubscription "viresent - Microsoft Azure Internal Consumption"


# ARP table for Azure private peering - Primary path
write "Primary Link"
Get-AzExpressRouteCircuitARPTable -ResourceGroupName $RG -ExpressRouteCircuitName $Name -PeeringType AzurePrivatePeering -DevicePath Primary

write "Secondary Link"
# ARP table for Azure private peering - Secondary path
Get-AzExpressRouteCircuitARPTable -ResourceGroupName $RG -ExpressRouteCircuitName $Name -PeeringType AzurePrivatePeering -DevicePath Secondary


