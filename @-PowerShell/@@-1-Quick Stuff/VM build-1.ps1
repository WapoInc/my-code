# Login to Azure
Get-AzSubscription
Select-AzSubscription -SubscriptionName "Enter your Sub name"

#Enter your variables

$RG = "Enter your Resource Group name"
$GateWayName = "Enter your ER or VPN Gateway name" 
$ER_Circuit_Name = "Enter your ER Circuit name"


#My own variables
Select-AzSubscription -SubscriptionName "viresent New AIRS" -Tenant MngEnv461963.onmicrosoft.com


# Variables for common values
$resourceGroup = "Bicep-VNET2"
$location = "SouthAfricaNorth"
$vmName = "VM-10-222-64-1"
$VM_Sku = "Standard_B2s"

#VNET + SubNet
$VNET ="10-222-64-0--19"
$SubNet1 = "SubNet-1"

# Create a resource group
New-AzResourceGroup -Name $resourceGroup -Location $location

# Create user object
$cred = Get-Credential -Message "Enter a username and password for the virtual machine."

# Create a VM
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

