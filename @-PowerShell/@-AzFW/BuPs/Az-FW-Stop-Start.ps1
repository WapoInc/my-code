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




# Stop an existing firewall

$azfw = Get-AzFirewall -Name "FW-Az-Stratus" -ResourceGroupName "Az-Stratus-rg"
$azfw.Deallocate()
Set-AzFirewall -AzureFirewall $azfw


# Start a firewall

$azfw = Get-AzFirewall -Name "FW-Az-Stratus" -ResourceGroupName "Az-Stratus-rg"
$vnet = Get-AzVirtualNetwork -ResourceGroupName "Az-Stratus-rg" -Name "VNET-Az-Stratus-asr"
$publicip1 = Get-AzPublicIpAddress -Name "AzFW-Az-Stratus-Pub-IP" -ResourceGroupName "Az-Stratus-rg"
$azfw.Allocate($vnet,@($publicip1))

Set-AzFirewall -AzureFirewall $azfw
