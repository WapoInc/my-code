# Start a Premium firewall in Forced Tunnel Mode
$azfw = Get-AzFirewall -Name "AzFW-ZA-East-vDC" -ResourceGroupName "ZA-East-vDC"
$azfw.Sku.Tier="Premium"
$vnet = Get-AzVirtualNetwork -ResourceGroupName "ZA-East-vDC" -Name "ZA-East-vDC-vnet"
$publicip = Get-AzPublicIpAddress -Name "AzFW-ZA-East-vDC-Pub-IP" -ResourceGroupName "ZA-East-vDC"
$mgmtPip = Get-AzPublicIpAddress -ResourceGroupName "ZA-East-vDC"-Name "Management-AzFW-ZA-East-vDC-Pub-IP"
$azfw.Allocate($vnet,$publicip,$mgmtPip)
Set-AzFirewall -AzureFirewall $azfw
