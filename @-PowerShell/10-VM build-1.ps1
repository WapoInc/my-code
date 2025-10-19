#Connect to your Azure Subscription.
Connect-AzAccount
#-------------------------------------------------------------------------------------------------------------------------------------
#If you have more than one subscription, get a list of your Azure subscriptions.
Get-AzSubscription
#-------------------------------------------------------------------------------------------------------------------------------------
#Specify the subscription that you want to use.
#Select-AzSubscription -SubscriptionName "Name of subscription"

Select-AzSubscription -SubscriptionName "viresent - AIRS"


# Variables for common values
$resourceGroup = "ANM-PoC"
$location = "westcentralus"
$vmName = "VM-2"

# Create user object
$cred = Get-Credential -Message "Enter a username and password for the virtual machine."

# Create a resource group
New-AzResourceGroup -Name $resourceGroup -Location $location

# Create a virtual machine
New-AzVM `
  -ResourceGroupName $resourceGroup `
  -Name $vmName `
  -Location $location `
  -Image "Win2016Datacenter" `
  -VirtualNetworkName "10-13-Spoke" `
  -SubnetName "10-13-SubNet" `
  -SecurityGroupName "myNetworkSecurityGroup" `
  -PublicIpAddressName "myPublicIp-2" `
  -Credential $cred `
  -OpenPorts 3389