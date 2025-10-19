
# Login to Azure
Connect-AzAccount -Tenant MngEnv461963.onmicrosoft.com
Get-AzSubscription
Select-AzSubscription -SubscriptionName "Enter your Sub name"

#Enter your variables

$RG = "Enter your Resource Group name"
$GateWayName = "Enter your ER or VPN Gateway name" 
$ER_Circuit_Name = "Enter your ER Circuit name"


#My own variables
Select-AzSubscription -SubscriptionName "viresent New AIRS" -Tenant MngEnv461963.onmicrosoft.com



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
# Stop an existing firewall in AIRS or NEW - AIRS in ZA-East-vDC
$azfw = Get-AzFirewall -Name "AzFW-ZA-East-vDC" -ResourceGroupName "ZA-East-vDC"
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
$azfw = Get-AzFirewall -Name "AzFW-vWAN-Hub-VNET" -ResourceGroupName "ZA-East-vDC"
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
# vWAN AzFW's
=========================================================================================
# Start a Premium firewall in vWAN

# ZAN Hub
$virtualhub = get-azvirtualhub -ResourceGroupName vWAN-Routing-Intent-PoC -name ZAN-Hub
$firewall = Get-AzFirewall -Name "AzureFirewall_ZAN-Hub" -ResourceGroupName "vWAN-Routing-Intent-PoC"
$firewall.Allocate($virtualhub.Id)
$firewall | Set-AzFirewall
Set-AzFirewall -AzureFirewall $firewall

# ZAN Hub
$virtualhub = get-azvirtualhub -ResourceGroupName vWAN-Routing-Intent-PoC -name ZAN-Hub2
$firewall = Get-AzFirewall -Name "AzureFirewall_ZAN-Hub2" -ResourceGroupName "vWAN-Routing-Intent-PoC"
$firewall.Allocate($virtualhub.Id)
$firewall | Set-AzFirewall
Set-AzFirewall -AzureFirewall $firewall


# WEU Hub
$virtualhub = get-azvirtualhub -ResourceGroupName vWAN-Routing-Intent-PoC -name WEU
$firewall = Get-AzFirewall -Name "AzureFirewall_WEU" -ResourceGroupName "vWAN-Routing-Intent-PoC"
$firewall.Allocate($virtualhub.Id)
$firewall | Set-AzFirewall
Set-AzFirewall -AzureFirewall $firewall




=========================================================================================
# Stop an existing firewall in vWAN in AIRS or NEW - AIRS in ZA-East-vDC
# ZAN
$firewall = Get-AzFirewall -Name "AzureFirewall_ZAN-Hub" -ResourceGroupName "vWAN-Routing-Intent-PoC"
$firewall.Deallocate()
$firewall | Set-AzFirewall
Set-AzFirewall -AzureFirewall $firewall

# ZAN-Hub2
$firewall = Get-AzFirewall -Name "AzureFirewall_ZAN-Hub2" -ResourceGroupName "vWAN-Routing-Intent-PoC"
$firewall.Deallocate()
$firewall | Set-AzFirewall
Set-AzFirewall -AzureFirewall $firewall

# WEU
$firewall = Get-AzFirewall -Name "AzureFirewall_WEU" -ResourceGroupName "vWAN-Routing-Intent-PoC"
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