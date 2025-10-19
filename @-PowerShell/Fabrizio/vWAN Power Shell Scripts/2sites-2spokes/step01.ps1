###########################################
# 
# Setup list:
# - Create a resource Group
# - Create a Virtual WAN
# - Create a Virtual Hub
# - Create a VPN Gateway in the Virtual Hub
#
###########################################
# Reference:
#   https://docs.microsoft.com/en-us/powershell/module/Az.network/get-Azvirtualwan
#   https://docs.microsoft.com/en-us/powershell/module/Az.network/new-Azvirtualwan
#   https://docs.microsoft.com/en-us/powershell/module/Az.network/get-Azvirtualhub
#   https://docs.microsoft.com/en-us/powershell/module/Az.network/new-Azvirtualhub
#   https://docs.microsoft.com/en-us/powershell/module/Az.network/update-Azvirtualhub
#
#   https://docs.microsoft.com/en-us/powershell/module/Az.network/remove-Azvirtualwan
#   https://docs.microsoft.com/en-us/powershell/module/Az.network/remove-Azvirtualhubvnetconnection
#   https://docs.microsoft.com/en-us/powershell/module/Az.network/remove-Azvirtualhub
# 
#   https://docs.microsoft.com/en-us/powershell/module/Az.network/new-Azvpngateway
#   https://docs.microsoft.com/en-us/powershell/module/Az.network/get-Azvirtualwanvpnconfiguration
#   https://docs.microsoft.com/en-us/powershell/module/Az.network/Update-AzVpnSite
#
# check out the deployment:  https://aka.ms/azurecortex
##########################################
#
#
################ Variables
$subscriptionName= "Dele - Microsoft Azure Internal Consumption"                # name of the Azure subscription
$rgName          = "vWAN-rg"                        # name of the resoure group
$location        = "southafricanorth"               # location of the hub
$vWANName        = "vWAN-Multi-Sub"                           # name Virtual Wan
$hubName         = "Dele-SA-North-Hub"                   # name of the Virtual Hub
$vHub1Prefix     = "10.104.0.0/24"                  # address prefix of the Virtual Hub
$vpnGtwHubName   = "Dele-SA-North-Hub-VPN-GW" # name VPN Gateway in the Virtual Hub
################
#
# Select the Azure subscription
$subscr=Get-AzSubscription -SubscriptionName $subscriptionName
Select-AzSubscription -SubscriptionId $subscr.Id 

## Create Resource Group
try {     
    Get-AzResourceGroup -Name $rgName -Location $location -ErrorAction Stop     
    Write-Host 'RG already exists... skipping' -foregroundcolor Green -backgroundcolor Black
} catch {     
    $rg = New-AzResourceGroup -Name $rgName -Location $location  -Force
}


## Create Virtual WAN
try {
  $virtualWan=Get-AzVirtualWan -ResourceGroupName $rgName -Name $vWANName -ErrorAction Stop
  Write-Host 'Virtual WAN '$vWANName' already exists... skipping' -foregroundcolor  Green -backgroundcolor Black
} catch {
  # Creates an Azure Virtual WAN
  $virtualWan = New-AzVirtualWan -ResourceGroupName $rgName -Name $vWANName -Location $location -AllowBranchToBranchTraffic -AllowVnetToVnetTraffic -Verbose
}

## Create Virtual Hub
try {
   $vhub=Get-AzVirtualHub -ResourceGroupName $rgName -Name $hubName 
   if ([string]::IsNullOrEmpty($vhub))
   {
      # Creates an Azure Virtual Hub
      $vhub=New-AzVirtualHub -VirtualWanId $virtualWan.Id -ResourceGroupName $rgName -Name $hubName -AddressPrefix $vHub1Prefix -Location $location
   } else
   {
      Write-Host 'Virtual Hub: '$hubName' already exists... skipping' -foregroundcolor  Green -backgroundcolor Black
   }
} catch {
   Write-Host 'error in create Virtual Hub: '$hubName'' -foregroundcolor  Green -backgroundcolor Black
}

# New-AzVpnGateway creates a scalable VPN Gateway in the Virtual Hub. 
# This is a connectivity for site-to-site connections and point-to-site inside the VirtualHub.
# This gateway resizes and scales based on the scale unit specified in this or the Set-AzVpnGateway cmdlet.
# The VpnGateway will be in the same location as the referenced VirtualHub.
try {
   Get-AzVpnGateway -ResourceGroupName $rgName -Name $vpnGtwHubName  -ErrorAction Stop
   Write-Host 'Virtual Hub VPN Gateway: '$vpnGtwHubName' already exists... skipping' -foregroundcolor  Green -backgroundcolor Black
} catch
{
   # VpnGatewayScaleUnit 1 -> 500Mbps
   New-AzVpnGateway -ResourceGroupName $rgName -Name $vpnGtwHubName -VpnGatewayScaleUnit 1 -VirtualHubId $vhub.Id 
}


