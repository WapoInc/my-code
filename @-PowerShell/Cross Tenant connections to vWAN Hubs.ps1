
Visual Studio Tenant ID : 6fe43f5b-2756-4cb3-a808-b8a71f2af1dc
Visual Studio Sub ID: fb34c8b3-e689-4f2b-aa06-83eb9517a4aa

AIRS Tenant ID: 72f988bf-86f1-41af-91ab-2d7cd011db47
AIS Sub ID: d062d828-c0dd-4884-8ac1-9db448832345


#From Parent ID (where the vWAN instance is residing)
Connect-AzAccount -SubscriptionId "d062d828-c0dd-4884-8ac1-9db448832345" -TenantId "72f988bf-86f1-41af-91ab-2d7cd011db47"
Get-AzSubscription



#From Remote ID (where the VNET that will be Connected is residing)
Select-AzSubscription -SubscriptionId "fb34c8b3-e689-4f2b-aa06-83eb9517a4aa"
$remote = Get-AzVirtualNetwork -Name "Spoke-VNET-in-VS" -ResourceGroupName "ER-Circuit-Auth-PoC"

#Parent ID
Select-AzSubscription -SubscriptionId "d062d828-c0dd-4884-8ac1-9db448832345"
New-AzVirtualHubVnetConnection -ResourceGroupName "vWAN-Custom-Routing-PoC" -VirtualHubName "SA-North" -Name "Spoke-to-VisualStudio-Sub" -RemoteVirtualNetwork $remote

