$Location1 = "SouthAfricaNorth"
$RG1 = "vmr-AzFW-PS-PoC"
$VNetnameHub = "vmr-Az-FW-Hub"
$SNOnpremPrefix = "1.1.1.0/24"
$VNetSpokePrefix = "2.2.2.0/24"

Set-AzResourceGroup -Name $RG1 -Tag @{}


# Get a Public IP for the firewall
$FWpip = New-AzPublicIpAddress -Name "fw-pip" -ResourceGroupName $RG1 `
  -Location $Location1 -AllocationMethod Static -Sku Standard
# Create the firewall
$Azfw = New-AzFirewall -Name AzFW01 -ResourceGroupName $RG1 -Location $Location1 -VirtualNetworkName $VNetnameHub -PublicIpName fw-pip
#Save the firewall private IP address for future use


$AzfwPrivateIP = $Azfw.IpConfigurations.privateipaddress
$AzfwPrivateIP



$Rule1 = New-AzFirewallNetworkRule -Name "AllowWeb" -Protocol TCP -SourceAddress $SNOnpremPrefix `
   -DestinationAddress $VNetSpokePrefix -DestinationPort 80
$Rule2 = New-AzFirewallNetworkRule -Name "AllowRDP" -Protocol TCP -SourceAddress $SNOnpremPrefix `
   -DestinationAddress $VNetSpokePrefix -DestinationPort 3389
$Rule3 = New-AzFirewallNetworkRule -Name "AllowSSH" -Protocol TCP -SourceAddress $SNOnpremPrefix `
   -DestinationAddress $VNetSpokePrefix -DestinationPort 22



#------------------------------------------------------------------------------------------
$NetRuleCollection1 = New-AzFirewallNetworkRuleCollection -Name RCNet100 -Priority 100 `
   -Rule $Rule1,$Rule2 -ActionType "Allow"
$NetRuleCollection2 = New-AzFirewallNetworkRuleCollection -Name RCNet200 -Priority 200 `
   -Rule $Rule3 -ActionType "Allow"

$Azfw.NetworkRuleCollections = $NetRuleCollection1,$NetRuleCollection2
Set-AzFirewall -AzureFirewall $Azfw
#------------------------------------------------------------------------------------------


