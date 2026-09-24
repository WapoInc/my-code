# My script to stop and start an existing Azure Firewall in New AIRS ZA-East-vDC
#
#
# Connect to your Azure Subscription.

Get-AzContext

Connect-AzAccount -DeviceCode

Connect-AzAccount -Tenant MngEnv461963.onmicrosoft.com -SubscriptionName "viresent-New-AIRS"
Connect-AzAccount -Tenant MngEnvMCAP056429.onmicrosoft.com -SubscriptionName "ME-MngEnvMCAP056429-Connectivity"


Select-AzSubscription -SubscriptionName "viresent-New-AIRS" -Tenant MngEnv461963.onmicrosoft.com

#----------------------------------------------------------------------------------------
# If you have more than one subscription, get a list of your Azure subscriptions.
Get-AzSubscription
#----------------------------------------------------------------------------------------
# Specify the subscription that you want to use.
Select-AzSubscription -SubscriptionName "viresent-New-AIRS"
########################################################################################
# Stop the Azure Firewall.
########################################################################################
$SubscriptionId = '0cfd0d2a-2b38-4c93-ba14-cf79185bc683'
$ResourceGroupName = 'za-east-southafricanorth'
$FirewallName = 'AzFW-ZA-East-southafricanorth'

Set-AzContext -SubscriptionId $SubscriptionId -ErrorAction Stop | Out-Null

$firewall = Get-AzFirewall `
	-Name $FirewallName `
	-ResourceGroupName $ResourceGroupName `
	-ErrorAction Stop

$firewall.Deallocate()
Set-AzFirewall -AzureFirewall $firewall -ErrorAction Stop

$firewall = Get-AzFirewall `
	-Name $FirewallName `
	-ResourceGroupName $ResourceGroupName `
	-ErrorAction Stop

Write-Host "Firewall IP configuration count: $($firewall.IpConfigurations.Count)"

########################################################################################
# Start the Azure Firewall.
########################################################################################
$SubscriptionId = '0cfd0d2a-2b38-4c93-ba14-cf79185bc683'
$ResourceGroupName = 'za-east-southafricanorth'
$FirewallName = 'AzFW-ZA-East-southafricanorth'
$VirtualNetworkName = 'za-east-southafricanorth-vnet'
$PublicIpName = 'AzFW-ZA-East-southafricanorth-pip'

Set-AzContext -SubscriptionId $SubscriptionId -ErrorAction Stop | Out-Null

$firewall = Get-AzFirewall `
	-Name $FirewallName `
	-ResourceGroupName $ResourceGroupName `
	-ErrorAction Stop

$virtualNetwork = Get-AzVirtualNetwork `
	-Name $VirtualNetworkName `
	-ResourceGroupName $ResourceGroupName `
	-ErrorAction Stop

$publicIp = Get-AzPublicIpAddress `
	-Name $PublicIpName `
	-ResourceGroupName $ResourceGroupName `
	-ErrorAction Stop

$firewall.Allocate($virtualNetwork, @($publicIp))
Set-AzFirewall -AzureFirewall $firewall -ErrorAction Stop

$firewall = Get-AzFirewall `
	-Name $FirewallName `
	-ResourceGroupName $ResourceGroupName `
	-ErrorAction Stop

Write-Host "Firewall IP configuration count: $($firewall.IpConfigurations.Count)"
########################################################################################
########################################################################################


########################################################################################
########################################################################################
# Start all test VM's
Start-AzVM -ResourceGroupName ZA-East-vDC -Name Win11-ZA-East-vDC -AsJob
Start-AzVM -ResourceGroupName ZA-East-vDC -Name JumpBox-ZA-East-Hub -AsJob
Start-AzVM -ResourceGroupName ZA-East-vDC -Name JumpBox-3-ZA-East-Hub -AsJob
Start-AzVM -ResourceGroupName ZA-East-vDC -Name JumpBox-5-ZA-East-Hub -AsJob
Start-AzVM -ResourceGroupName ZA-East-vDC -Name Ping-Test -AsJob
Start-AzVM -ResourceGroupName ZA-East-vDC -Name VM-ZA-East-Spoke-1 -AsJob
Start-AzVM -ResourceGroupName ZA-East-vDC -Name VM-ZA-East-Spoke-2 -AsJob
Start-AzVM -ResourceGroupName ZA-East-vDC -Name VM-ZA-East-Spoke-3 -AsJob
########################################################################################
# Stop all test VM's
Stop-AzVM -ResourceGroupName ZA-East-vDC -Name Win11-ZA-East-vDC -Force -AsJob
Stop-AzVM -ResourceGroupName ZA-East-vDC -Name JumpBox-ZA-East-Hub -Force -AsJob
Stop-AzVM -ResourceGroupName ZA-East-vDC -Name JumpBox-3-ZA-East-Hub -Force -AsJob
Stop-AzVM -ResourceGroupName ZA-East-vDC -Name JumpBox-5-ZA-East-Hub -Force -AsJob
Stop-AzVM -ResourceGroupName ZA-East-vDC -Name Ping-Test -Force -AsJob
Stop-AzVM -ResourceGroupName ZA-East-vDC -Name VM-ZA-East-Spoke-1 -Force -AsJob
Stop-AzVM -ResourceGroupName ZA-East-vDC -Name VM-ZA-East-Spoke-2 -Force -AsJob
Stop-AzVM -ResourceGroupName ZA-East-vDC -Name VM-ZA-East-Spoke-3 -Force -AsJob
########################################################################################
#JumpBox-ZA-East-Hub
ping 10.20.1.4

# JumpBox-3-ZA-East-Hub
ping 10.20.1.5

ping 10.20.1.4
ping 10.20.1.6
########################################################################################
########################################################################################
########################################################################################

= Stop ==================================================================================
=========================================================================================
# Stop an existing firewall in New AIRS ZA-East-vDC
$azfw = Get-AzFirewall -Name "AzFW-ZA-East-vDC" -ResourceGroupName "ZA-East-vDC"
$azfw.Deallocate()
Set-AzFirewall -AzureFirewall $azfw

=========================================================================================
# Stop an existing firewall in AIRS ER-LTSA-RG
$azfw = Get-AzFirewall -Name "AzFW-ZA-North" -ResourceGroupName "ER-LTSA-RG"
$azfw.Deallocate()
Set-AzFirewall -AzureFirewall $azfw

=========================================================================================

# Stop an existing firewall in New AIRS ZA-East-vDC - vWAN Hub SA North
$azfw = Get-AzFirewall -Name "AzureFirewall_AVS-vWAN-Transit-Hub" -ResourceGroupName "AVS-ZA-North"
$azfw.Deallocate()
Set-AzFirewall -AzureFirewall $azfw



= Start =================================================================================
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






=========================================================================================
=========================================================================================
=========================================================================================
# vWAN AzFW's  // AzureFirewall_AVS-vWAN-Transit-Hub
=========================================================================================
=========================================================================================
=========================================================================================
$RG =            "AVS-ZA-North"
$AzFWName =      "AzureFirewall_AVS-vWAN-Transit-Hub"

=========================================================================================
# Start a Premium firewall in vWAN
$virtualhub = Get-azvirtualhub -ResourceGroupName "AVS-ZA-North" -name "AVS-vWAN-Transit-Hub"
$firewall = Get-AzFirewall -Name $AzFWName -ResourceGroupName $RG
$firewall.Allocate($virtualhub.Id)
$firewall | Set-AzFirewall
Set-AzFirewall -AzureFirewall $firewall
=========================================================================================
# Stop an existing firewall in vWAN in AIRS or NEW - AIRS in ZA-East-vDC
$firewall = Get-AzFirewall -Name $AzFWName -ResourceGroupName $RG
$firewall.Deallocate()
$firewall | Set-AzFirewall
Set-AzFirewall -AzureFirewall $firewall
=========================================================================================
=========================================================================================
=========================================================================================




















=========================================================================================
# Create a FW Rule
$azfw = Get-AzFirewall -Name "FW-Az-Stratus" -ResourceGroupName "Az-Stratus-rg"
$NetRule1 = New-AzFirewallNetworkRule -Name "vmr1" -Protocol TCP -SourceAddress 1.1.1.0/24 -DestinationAddress 11.11.11.11 -DestinationPort 22
$NetRuleCollection = New-AzFirewallNetworkRuleCollection -Name vmr1 -Priority 111 -Rule $NetRule1 -ActionType "Allow"
$Azfw.NetworkRuleCollections.Add($NetRuleCollection)
Set-AzFirewall -AzureFirewall $azfw



=========================================================================================
# Network rule name logging (preview)
Connect-AzAccount 
Select-AzSubscription -Subscription "@viresent - New AIRS-ME-MngEnv461963" 
Register-AzProviderFeature -FeatureName AFWEnableNetworkRuleNameLogging -ProviderNamespace Microsoft.Network
Register-AzResourceProvider -ProviderNamespace Microsoft.Network