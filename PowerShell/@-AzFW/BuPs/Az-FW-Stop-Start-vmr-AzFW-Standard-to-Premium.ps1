# Connect to your Azure Subscription.
Connect-AzAccount

#-------------------------------------------------------------------------------------------------------------------------------------
# If you have more than one subscription, get a list of your Azure subscriptions.
Get-AzSubscription

#-------------------------------------------------------------------------------------------------------------------------------------
# Specify the subscription that you want to use.
Select-AzSubscription -SubscriptionName "Name of subscription"
Select-AzSubscription -SubscriptionName "@viresent - AIRS"


# Create a FW Rule
$azfw = Get-AzFirewall -Name "FW-Az-Stratus" -ResourceGroupName "Az-Stratus-rg"
$NetRule1 = New-AzFirewallNetworkRule -Name "vmr1" -Protocol TCP -SourceAddress 1.1.1.0/24 -DestinationAddress 11.11.11.11 -DestinationPort 22
$NetRuleCollection = New-AzFirewallNetworkRuleCollection -Name vmr1 -Priority 111 -Rule $NetRule1 -ActionType "Allow"
$Azfw.NetworkRuleCollections.Add($NetRuleCollection)
Set-AzFirewall -AzureFirewall $azfw
=========================================================================================
# Stop an existing firewall
$azfw = Get-AzFirewall -Name "AzFW-ZA-East-vDC" -ResourceGroupName "ZA-East-vDC"
$azfw.Deallocate()
Set-AzFirewall -AzureFirewall $azfw

=========================================================================================
# Start a Premium firewall
$azfw = Get-AzFirewall -Name "AzFW-ZA-East-vDC" -ResourceGroupName "ZA-East-vDC"
$azfw.Sku.Tier="Premium"
$vnet = Get-AzVirtualNetwork -ResourceGroupName "ZA-East-vDC" -Name "ZA-East-vDC-vnet"
$publicip1 = Get-AzPublicIpAddress -Name "AzFW-ZA-East-vDC-Pub-IP" -ResourceGroupName "ZA-East-vDC"
$azfw.Allocate($vnet,@($publicip1))
Set-AzFirewall -AzureFirewall $azfw

=========================================================================================
# Start a Standard firewall
$azfw = Get-AzFirewall -Name "AzFW-ZA-East-vDC" -ResourceGroupName "ZA-East-vDC"
$vnet = Get-AzVirtualNetwork -ResourceGroupName "ZA-East-vDC" -Name "ZA-East-vDC-vnet"
$publicip1 = Get-AzPublicIpAddress -Name "AzFW-ZA-East-vDC-Pub-IP" -ResourceGroupName "ZA-East-vDC"
$azfw.Allocate($vnet,@($publicip1))
Set-AzFirewall -AzureFirewall $azfw

=========================================================================================
# Start a Premium firewall in Forced Tunnel Mode
$azfw = Get-AzFirewall -Name "AzFW-ZA-East-vDC" -ResourceGroupName "ZA-East-vDC"
$azfw.Sku.Tier="Premium"
$vnet = Get-AzVirtualNetwork -ResourceGroupName "ZA-East-vDC" -Name "ZA-East-vDC-vnet"
$publicip = Get-AzPublicIpAddress -Name "AzFW-ZA-East-vDC-Pub-IP" -ResourceGroupName "ZA-East-vDC"
$mgmtPip = Get-AzPublicIpAddress -ResourceGroupName "ZA-East-vDC"-Name "Management-AzFW-ZA-East-vDC-Pub-IP"
$azfw.Allocate($vnet,$publicip,$mgmtPip)
Set-AzFirewall -AzureFirewall $azfw

=========================================================================================