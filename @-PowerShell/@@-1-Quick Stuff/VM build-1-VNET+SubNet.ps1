#Connect to your Azure Subscription.
Connect-AzAccount
#-------------------------------------------------------------------------------------------------------------------------------------
#If you have more than one subscription, get a list of your Azure subscriptions.
Get-AzSubscription
#-------------------------------------------------------------------------------------------------------------------------------------
#Specify the subscription that you want to use.
#Select-AzSubscription -SubscriptionName "Name of subscription"

Select-AzSubscription -SubscriptionName "@viresent - AIRS"


# Variables for common values
$resourceGroup = "ZA-East-vDC"
$location = "SouthAfricaNorth"
$vmName = "VM-10-15"
$VM_Sku = "Standard_B2s"

#VNET + SubNet
$VNET     = "vDC-Spoke-10-15"
$SubNet1  = "SubNet-1"

# Create user object
# $cred = Get-Credential -Message "Enter a username and password for the virtual machine."

# Create a resource group
New-AzResourceGroup -Name $resourceGroup -Location $location

# Create VNET + SubNet
$VNET              = "vDC-Spoke-10-15"
$AddressPrefix     = "10.15.0.0/24"
$SubNet1           = "10.15.0.0/25"


New-AzVirtualNetwork `
     -Name $VNET `
     -ResourceGroupName $resourceGroup `
     -Location $location `
     -AddressPrefix $AddressPrefix `
     -Subnet $SubNet1

#-----------------------------------------------------------
     $vnet = @{
    Name = 'vDC-Spoke-10-15'
    ResourceGroupName = 'ZA-East-vDC'
    Location = 'SouthAfricaNorth'
    AddressPrefix = '10.15.0.0/24'    
}
$virtualNetwork = New-AzVirtualNetwork @vnet

$subnet = @{
    Name = 'Subnet-1'
    VirtualNetwork = $virtualNetwork
    AddressPrefix = '10.15.0.0/25'
}
$subnetConfig = Add-AzVirtualNetworkSubnetConfig @subnet

$virtualNetwork | Set-AzVirtualNetwork
#-----------------------------------------------------------


# Create a virtual machine
New-AzVM `
  -ResourceGroupName $resourceGroup `
  -Name $vmName `
  -Location $location `
  -Image "Win2016Datacenter" `
  -Size $VM_Sku `
  -VirtualNetworkName $virtualNetwork `
  -AddressPrefix $AddressPrefix `
  -SubnetName = "SubNet-1" `
  -SubnetAddressPrefix $SubNet1 `
  -SecurityGroupName "$vmName-NSG" `
  -PublicIpAddressName "$vmNAME-Pub-IP" `
  -Credential $cred `
  -OpenPorts 3389


