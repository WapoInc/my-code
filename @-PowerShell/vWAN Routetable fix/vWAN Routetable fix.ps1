
Connect-AzAccount
Get-AzSubscription
Select-AzSubscription -SubscriptionName "@viresent - AIRS"




$rt = Get-AzVHubRouteTable -ResourceGroupName MTN-vWAN-Demo-rg -ParentResourceName ZAW_HUB -Name RouteTable-defaultRouteTable -debug -verbose

$rt = Get-AzVHubRouteTable -ResourceGroupName MTN-vWAN-Demo-rg -ParentResourceName ZAW_HUB -Name RouteTable-noneRouteTable -debug -verbose

Update-AzVHubRouteTable -InputObject $rt -debug -verbose  -debug -verbose

Get/Put on the vhub without any changes to get it out of failed state
 
$hub = Get-AzVirtualHub -Name ZAW_HUB -ResourceGroupName MTN-vWAN-Demo-rg -debug -verbose
