#Connect to your Azure Subscription.
Connect-AzAccount
#-------------------------------------------------------------------------------------------------------------------------------------
#If you have more than one subscription, get a list of your Azure subscriptions.
Get-AzSubscription
#-------------------------------------------------------------------------------------------------------------------------------------
#Specify the subscription that you want to use.
#Select-AzSubscription -SubscriptionName "Dele - Microsoft Azure Internal Consumption"
Select-AzSubscription -SubscriptionName "Name of subscription"

#-------------------------------------------------------------------------------------------------------------------------------------
#-------------------------------------------------------------------------------------------------------------------------------------
#Virtual Network Name = "TestVNet"
#Virtual Network address space = 123.1.0.0/16
#Resource Group = "TestRG"
#Subnet1 Name = "SubNet-1"
#Subnet1 address space = "123.1.0.0/24"
#Gateway Subnet name: "GatewaySubnet" You must always name a Gateway Subnet GatewaySubnet.
#Gateway Subnet address space = "123.1.0.0/26"
#Region = "SouthAfricaNorth"
#Gateway Name = "GW"
#Gateway IP Name = "GWIP"
#Gateway IP configuration Name = "gwipconf"
#Type = "ExpressRoute" This type is required for an ExpressRoute configuration.
#Gateway Public IP Name = "gwpip"
#-------------------------------------------------------------------------------------------------------------------------------------
#-------------------------------------------------------------------------------------------------------------------------------------
#Declare your variables for this exercise. 
#Be sure to edit the sample to reflect the settings that you want to use.
$RG = "TestRG-2"
$Location = "SouthAfricaNorth"
$GWName = "GW"
$GWIPName = "GWIP"
$GWIPconfName = "gwipconf"
$VNetName = "TestVNet"
#-------------------------------------------------------------------------------------------------------------------------------------
# Create a resource group
New-AzResourceGroup -Name $RG -Location $Location


#-------------------------------------------------------------------------------------------------------------------------------------
# Create a VNET
New-AzVirtualNetwork -Name $VNetName -ResourceGroupName $RG -Location SouthAfricaNorth -AddressPrefix 123.1.0.0/16  


#-------------------------------------------------------------------------------------------------------------------------------------
#Store the virtual network object as a variable.
$vnet = Get-AzVirtualNetwork -Name $VNetName -ResourceGroupName $RG


#-------------------------------------------------------------------------------------------------------------------------------------
# Create a GateWay Subnet + Subnet-1 + SubNet-2 to your Virtual Network
Add-AzVirtualNetworkSubnetConfig -Name GatewaySubnet -VirtualNetwork $vnet -AddressPrefix 123.1.0.0/26
Add-AzVirtualNetworkSubnetConfig -Name SubNet1 -VirtualNetwork $vnet -AddressPrefix 123.1.1.0/24
Add-AzVirtualNetworkSubnetConfig -Name SubNet2 -VirtualNetwork $vnet -AddressPrefix 123.1.2.0/24

#-------------------------------------------------------------------------------------------------------------------------------------
#Set the configuration.
$vnet = Set-AzVirtualNetwork -VirtualNetwork $vnet


#-------------------------------------------------------------------------------------------------------------------------------------
#Store the gateway subnet as a variable.
$subnet = Get-AzVirtualNetworkSubnetConfig -Name 'GatewaySubnet' -VirtualNetwork $vnet


#-------------------------------------------------------------------------------------------------------------------------------------
#Request a public IP address. The IP address is requested before creating the gateway. You cannot specify the IP address that you want to use; it’s dynamically allocated. You'll use this IP address in the next configuration section. The AllocationMethod must be Dynamic.
$pip = New-AzPublicIpAddress -Name $GWIPName  -ResourceGroupName $RG -Location $Location -AllocationMethod Dynamic


#-------------------------------------------------------------------------------------------------------------------------------------
#Create the configuration for your gateway. The gateway configuration defines the subnet and the public IP address to use. In this step, you are specifying the configuration that will be used when you create the gateway. This step does not actually create the gateway object. Use the sample below to create your gateway configuration.
$ipconf = New-AzVirtualNetworkGatewayIpConfig -Name $GWIPconfName -Subnet $subnet -PublicIpAddress $pip


#-------------------------------------------------------------------------------------------------------------------------------------
#Create the gateway. In this step, the -GatewayType is especially important. You must use the value ExpressRoute. After running these cmdlets, the gateway can take 45 minutes or more to create.
New-AzVirtualNetworkGateway -Name $GWName -ResourceGroupName $RG -Location $Location -IpConfigurations $ipconf -GatewayType Expressroute -GatewaySku Standard


#-------------------------------------------------------------------------------------------------------------------------------------
