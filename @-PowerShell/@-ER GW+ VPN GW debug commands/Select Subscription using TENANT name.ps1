Connect-AzAccount -Tenant mtn.com
Get-AzSubscription
Set-AzContext -Tenant mtn.com -Subscription "gp-coe-ant-prd-1"
Select-AzSubscription -SubscriptionName "gp-coe-ant-prd-1" -Tenant mtn.com $RG = "rg-za-5gc-sbx-san-1"


$GateWayName = "lngw-za-5gc-sbx-san-1" 
$ER_Circuit_Name = "erc-za-5gc-sbx-san-2" Get-AzExpressRouteCircuit -ResourceGroupName $RG -Name $ER_Circuit_Name

