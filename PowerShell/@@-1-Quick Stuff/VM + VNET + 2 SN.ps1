# Use this PSD script to build a VNET with 2 SubNets and 1 VM of Size you select
#
#
#
#
#Connect to your Azure Subscription.
Connect-AzAccount
#-------------------------------------------------------------------------------------------------------------------------------------
#If you have more than one subscription, get a list of your Azure subscriptions.
Get-AzSubscription
#-------------------------------------------------------------------------------------------------------------------------------------
#Specify the subscription that you want to use.
#Select-AzSubscription -SubscriptionName "Name of subscription"

Select-AzSubscription -SubscriptionName "@viresent - AIRS"

#=1===============================================================================================================
#VNET + Subnet Building
#
$Location           = 'SouthAfricaNorth'
$ResourceGroup      = 'ZA-East-vDC'
$VNET_Name          = 'vDC-Spoke-10-15'
$VM_Sku             = "Standard_B2s"
$AddressPrefix      = "10.15.0.0/24"
#
New-AzResourceGroup -Name $ResourceGroup -Location $Location
#
$SubNet1     = New-AzVirtualNetworkSubnetConfig -Name SubNet1 -AddressPrefix "10.15.0.0/25"
#
New-AzVirtualNetwork `
     -Name $VNET_Name `
     -ResourceGroupName $ResourceGroup `
     -Location $Location `
     -AddressPrefix $AddressPrefix `
     -Subnet $SubNet1







#================================================================================================================
# Create user object
$cred = Get-Credential -Message "Enter a username and password for the virtual machine."
#================================================================================================================
# Build VM 
$vmName = "VM-10-15"
# Create a virtual machine
  New-AzVM `
  -ResourceGroupName $resourceGroup `
  -Name $vmName `
  -Location $location `
  -Credential $cred `
  -Image "Win2016Datacenter" `
  -VirtualNetworkName $VNET_Name `
  -SubnetName "SubNet1" `
  -PublicIpAddressName "$vmNAME-Pub-IP" `
  -SecurityGroupName "$vmName-NSG" `
  -OpenPorts 3389
#
#
#
#
#
#
#=2===============================================================================================================
#VNET + Subnet Building
#
$Location           = 'SouthAfricaNorth'
$ResourceGroup      = 'ZA-East-vDC'
$VNET_Name          = 'ZA-East-vDC-Spoke-10-15'
$VM_Sku             = "Standard_B2s"
$AddressPrefix      = "10.15.0.0/24"
#
New-AzResourceGroup -Name $ResourceGroup -Location $Location
#
$SubNet1     = New-AzVirtualNetworkSubnetConfig -Name SubNet1 -AddressPrefix "10.15.0.0/25"
$SubNet2     = New-AzVirtualNetworkSubnetConfig -Name SubNet2 -AddressPrefix "10.15.0.128/25"
#
New-AzVirtualNetwork `
     -Name $VNET_Name `
     -ResourceGroupName $ResourceGroup `
     -Location $Location `
     -AddressPrefix $AddressPrefix `
     -Subnet $SubNet1,$SubNet2





#================================================================================================================
# Build VM 
$vmName = "VM1-Spoke-10-15"
# Create a virtual machine
  New-AzVM `
  -ResourceGroupName $resourceGroup `
  -Name $vmName `
  -Location $location `
  -Credential $cred `
  -Image "Win2016Datacenter" `
  -VirtualNetworkName $VNET_Name `
  -SubnetName "SubNet1" `
  -PublicIpAddressName "$vmNAME-Pub-IP" `
  -SecurityGroupName "$vmName-NSG" `
  -OpenPorts 3389
  #
#=3===============================================================================================================
#VNET + Subnet Building
#
$Location           = 'SouthAfricaNorth'
$ResourceGroup      = 'vWAN-Custom-Routing-PoC'
$VNET_Name          = 'SA-North-2-Spoke-3'
$VM_Sku             = "Standard_B2s"
$AddressPrefix      = "172.23.23.0/24"
#
New-AzResourceGroup -Name $ResourceGroup -Location $Location
#
$SubNet1     = New-AzVirtualNetworkSubnetConfig -Name SubNet1 -AddressPrefix "172.23.23.0/25"
$SubNet2     = New-AzVirtualNetworkSubnetConfig -Name SubNet2 -AddressPrefix "172.23.23.128/25"
#
New-AzVirtualNetwork `
     -Name $VNET_Name `
     -ResourceGroupName $ResourceGroup `
     -Location $Location `
     -AddressPrefix $AddressPrefix `
     -Subnet $SubNet1,$SubNet2
#================================================================================================================
# Build VM 
$vmName = "VM3-SAN2-Spoke3"
# Create a virtual machine
  New-AzVM `
  -ResourceGroupName $resourceGroup `
  -Name $vmName `
  -Location $location `
  -Credential $cred `
  -Image "Win2016Datacenter" `
  -VirtualNetworkName $VNET_Name `
  -SubnetName "SubNet1" `
  -PublicIpAddressName "$vmNAME-Pub-IP" `
  -SecurityGroupName "$vmName-NSG" `
  -OpenPorts 3389
  #
  #================================================================================================================

