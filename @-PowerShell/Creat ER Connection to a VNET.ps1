## Reset a peering ##
# Login to Az
Connect-AzAccount
# If you have multiple Azure subscriptions, check the subscriptions for the account.
Get-AzSubscription
# Specify the subscription that you want to use.
Select-AzSubscription -SubscriptionName "viresent - AIRS"
#
#
$circuit = Get-AzExpressRouteCircuit -Name "ER-LTSA-SA-North" -ResourceGroupName "ER-LTSA-RG"
$gw = Get-AzVirtualNetworkGateway -Name "ERGW-ER-LTSA-SA-West" -ResourceGroupName "ER-LTSA-RG"
$connection = New-AzVirtualNetworkGatewayConnection -Name "ZAN-2-ZAW-Connection" -ResourceGroupName "ER-LTSA-RG" -Location "South Africa North" -VirtualNetworkGateway1 $gw -PeerId $circuit.Id -ConnectionType ExpressRoute
#
#
