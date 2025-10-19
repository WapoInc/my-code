

# Connect to your Azure Subscription.
Connect-AzAccount

#----------------------------------------------------------------------------------------
# If you have more than one subscription, get a list of your Azure subscriptions.
Get-AzSubscription

#----------------------------------------------------------------------------------------
# Specify the subscription that you want to use.
Select-AzSubscription -SubscriptionName "@viresent-New-AIRS"


########################################################################################
########################################################################################
########################################################################################
########################################################################################
# Test using variables #################################################################
$RG =            "ZA-East-vDC"
$VNETName =      "ZA-East-vDC-vnet"
$AzFWName =      "AzFW-ZA-East-vDC"
$AzFWName_PIP =  "AzFW-ZA-East-vDC-Pub-IP"

########################################################################################
# Stop an existing firewall in New AIRS ZA-East-vDC
$azfw = Get-AzFirewall -Name $AzFWName -ResourceGroupName $RG
$azfw.Deallocate()
Set-AzFirewall -AzureFirewall $azfw
########################################################################################
# Start a Premium firewall
$azfw = Get-AzFirewall -Name $AzFWNAme -ResourceGroupName $RG
$azfw.Sku.Tier="Premium"
$vnet = Get-AzVirtualNetwork -ResourceGroupName $RG -Name $VNETName
$publicip1 = Get-AzPublicIpAddress -Name $AzFWName_PIP -ResourceGroupName $RG
$azfw.Allocate($vnet,@($publicip1))
Set-AzFirewall -AzureFirewall $azfw
########################################################################################
########################################################################################
########################################################################################
########################################################################################
########################################################################################
# Start all test VM's
Start-AzVM -ResourceGroupName ZA-East-vDC -Name JumpBox-3-ZA-East-Hub -AsJob
Start-AzVM -ResourceGroupName ZA-East-vDC -Name Ping-Test -AsJob
Start-AzVM -ResourceGroupName ZA-East-vDC -Name VM-ZA-East-Spoke-1 -AsJob
Start-AzVM -ResourceGroupName ZA-East-vDC -Name VM-ZA-East-Spoke-2 -AsJob
Start-AzVM -ResourceGroupName ZA-East-vDC -Name VM-ZA-East-Spoke-3 -AsJob
########################################################################################
# Stop all test VM's
Stop-AzVM -ResourceGroupName ZA-East-vDC -Name JumpBox-3-ZA-East-Hub -Force -AsJob
Stop-AzVM -ResourceGroupName ZA-East-vDC -Name Ping-Test -Force -AsJob
Stop-AzVM -ResourceGroupName ZA-East-vDC -Name VM-ZA-East-Spoke-1 -Force -AsJob
Stop-AzVM -ResourceGroupName ZA-East-vDC -Name VM-ZA-East-Spoke-2 -Force -AsJob
Stop-AzVM -ResourceGroupName ZA-East-vDC -Name VM-ZA-East-Spoke-3 -Force -AsJob
########################################################################################
psping -t 10.20.1.5:22
psping -t 10.20.8.4:22
psping -t 10.21.1.4:22
psping -t 10.22.1.4:22
psping -t 10.23.1.4:22
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

# Stop an existing firewall in New AIRS ZA-East-vDC - vWAN Hub VNET
$azfw = Get-AzFirewall -Name "AzFW-vWAN-Hub-VNET" -ResourceGroupName "AVS-ZA-North"
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
# Start a Standard firewall in vWAN Hub VNET
$azfw = Get-AzFirewall -Name "AzFW-vWAN-Hub-VNET" -ResourceGroupName "AVS-ZA-North"
$vnet = Get-AzVirtualNetwork -ResourceGroupName "AVS-ZA-North" -Name "vWAN-Hub-VNET"
$publicip1 = Get-AzPublicIpAddress -Name "AzFW-vWAN-Hub-VNET-Pub-IP" -ResourceGroupName "AVS-ZA-North"
$azfw.Allocate($vnet,@($publicip1))
Set-AzFirewall -AzureFirewall $azfw




=========================================================================================
=========================================================================================
=========================================================================================
# vWAN AzFW's  // AzureFirewall_AVS-vWAN-Transit-Hub
=========================================================================================
=========================================================================================
=========================================================================================
// $RG =            "AVS-ZA-North"
// $AzFWName =      "AzureFirewall_AVS-vWAN-Transit-Hub"
// $AzFWName_PIP =  "AzFW-ZA-East-vDC-Pub-IP"
=========================================================================================
# Start a Premium firewall in vWAN
$virtualhub = Get-azvirtualhub -ResourceGroupName "AVS-ZA-North" -name "AVS-vWAN-Transit-Hub"
$firewall = Get-AzFirewall -Name "AzureFirewall_AVS-vWAN-Transit-Hub" -ResourceGroupName "AVS-ZA-North"
$firewall.Allocate($virtualhub.Id)
$firewall | Set-AzFirewall
Set-AzFirewall -AzureFirewall $firewall

=========================================================================================
# Stop an existing firewall in vWAN in AIRS or NEW - AIRS in ZA-East-vDC
$firewall = Get-AzFirewall -Name "AzureFirewall_AVS-vWAN-Transit-Hub" -ResourceGroupName "AVS-ZA-North"
$firewall.Deallocate()
$firewall | Set-AzFirewall
Set-AzFirewall -AzureFirewall $firewall



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