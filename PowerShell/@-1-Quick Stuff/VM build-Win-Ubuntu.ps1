# Login to Azure
Get-AzSubscription
Select-AzSubscription -SubscriptionName "Enter your Sub name"

#Enter your variables

#My own variables
Select-AzSubscription -SubscriptionName "viresent New AIRS" -Tenant MngEnv461963.onmicrosoft.com


# Variables for common values
$resourceGroup = "ZA-East-vDC"
$location = "SouthAfricaNorth"
$vmName = "VM1-Spoke-1"
$VM_Sku = "Standard_B2s"

#VNET + SubNet
$VNET_NAME ="neu-vnet-spoke-1"
$SubNet1 = "default"

# Create a resource group
New-AzResourceGroup -Name $resourceGroup -Location $location

# Create user object
$cred = Get-Credential -Message "Enter a username and password for the virtual machine."

# Create a Windows Server VM
New-AzVM `
  -ResourceGroupName $resourceGroup `
  -Name $vmName `
  -Location $location `
  -Image "Win2016Datacenter" `
  -Size $VM_Sku `
  -VirtualNetworkName $VNET `
  -SubnetName $SubNet1 `
  -SecurityGroupName "$vmName-NSG" `
  -PublicIpAddressName "$vmNAME-Pub-IP" `
  -Credential $cred `
  -OpenPorts 3389

# Create a Ubuntu VM 
New-AzVM `
  -ResourceGroupName $resourceGroup `
  -Name $vmName `
  -Location $location `
  -Credential $cred `
  -Image "Ubuntu2204" `
  -Size $VM_Sku `
  -VirtualNetworkName $VNET_NAME `
  -SubnetName $SubNet1 `
  -PublicIpAddressName "$vmNAME-Pub-IP" `
  -SecurityGroupName "$vmName-NSG" `
  -OpenPorts 22
