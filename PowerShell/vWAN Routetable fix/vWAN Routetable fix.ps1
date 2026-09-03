
Connect-AzAccount
Get-AzSubscription
Select-AzSubscription -SubscriptionName "viresent-New-AIRS"




$rt = Get-AzVHubRouteTable -ResourceGroupName Global-vWAN-rg -ParentResourceName ZAN-Hub-1 -Name RouteTable-defaultRouteTable -debug -verbose

$rt = Get-AzVHubRouteTable -ResourceGroupName Global-vWAN-rg -ParentResourceName ZAW-Hub-1 -Name RouteTable-noneRouteTable -debug -verbose

Update-AzVHubRouteTable -InputObject $rt -debug -verbose  -debug -verbose

Get/Put on the vhub without any changes to get it out of failed state
 
$hub = Get-AzVirtualHub -Name ZAN-Hub-1 -ResourceGroupName MTN-vWAN-Demo-rg -debug -verbose
$hub = Get-AzVirtualHub -Name ZAW-Hub-1 -ResourceGroupName MTN-vWAN-Demo-rg -debug -verbose
