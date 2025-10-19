# Deallocate the Standard Firewall

#. 



$azfw = Get-AzFirewall -Name "AzureFirewall_SA-North-2" -ResourceGroupName "vWAN-Custom-Routing-PoC"
$azfw.Deallocate()
Set-AzFirewall -AzureFirewall $azfw




# Allocate Firewall Premium

$azfw = Get-AzFirewall -Name -Name "AzureFirewall_SA-North-2" -ResourceGroupName "vWAN-Custom-Routing-PoC"
$hub = get-azvirtualhub -ResourceGroupName "vWAN-Custom-Routing-PoC" -name "SA-North-2"
$azfw.Sku.Tier="Premium"
$azfw.Allocate($hub.id)
Set-AzFirewall -AzureFirewall $azfw