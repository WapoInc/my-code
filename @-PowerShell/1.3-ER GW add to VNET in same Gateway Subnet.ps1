# Connect to your Azure Subscription.
Connect-AzAccount
 
#-------------------------------------------------------------------------------------------------------------------------------------
# If you have more than one subscription, get a list of your Azure subscriptions.
Get-AzSubscription
 
#-------------------------------------------------------------------------------------------------------------------------------------
# Specify the subscription that you want to use.
# Select-AzSubscription -SubscriptionName "Dele - Microsoft Azure Internal Consumption"
Select-AzSubscription -SubscriptionName "@viresent - AIRS"
#-------------------------------------------------------------------------------------------------------------------------------------
# Declare your variables for this exercise. 

#-1-##### Be sure to edit the sample to reflect the settings that you want to use.

$RG = "Az-Stratus-rg"
$Location = "SouthAfricaNorth"
$GWName = "ER-GW-Az-Stratus-ZAN"
$GWIPName = "ER-GW-Az-Stratus-ZAN-Pub-IP"
$GWIPconfName = "gwipconf"
$VNetName = "VNET-Az-Stratus-asr"
 
#################-------------------------------------------------------------------------------------------------------------------------------------
################# Create a resource group
################# New-AzResourceGroup -Name $RG -Location $Location
#################-------------------------------------------------------------------------------------------------------------------------------------
################# Create a VNET
# New-AzVirtualNetwork -Name $VNetName -ResourceGroupName $RG -Location SouthAfricaNorth -AddressPrefix 10.11.0.0/16  
#################-------------------------------------------------------------------------------------------------------------------------------------
 
 
 
# Store the virtual network object as a variable.

#-2-#####
$vnet = Get-AzVirtualNetwork -Name $VNetName -ResourceGroupName $RG
 
 
 
#################-------------------------------------------------------------------------------------------------------------------------------------
################# Add / Create a GateWay Subnet + Subnet-1 + SubNet-2 to your Virtual Network
# Add-AzVirtualNetworkSubnetConfig -Name GatewaySubnet -VirtualNetwork $vnet -AddressPrefix 10.11.0.0/24
################# Add-AzVirtualNetworkSubnetConfig -Name SubNet-1 -VirtualNetwork $vnet -AddressPrefix 10.1.1.0/24
################# Add-AzVirtualNetworkSubnetConfig -Name SubNet-2 -VirtualNetwork $vnet -AddressPrefix 10.1.2.0/24
#################-------------------------------------------------------------------------------------------------------------------------------------
# Set the configuration - Create the Subnets ....
# $vnet = Set-AzVirtualNetwork -VirtualNetwork $vnet
 
#-------------------------------------------------------------------------------------------------------------------------------------
# Store the gateway subnet as a variable.

#-3-#
$subnet = Get-AzVirtualNetworkSubnetConfig -Name 'GatewaySubnet' -VirtualNetwork $vnet
 
#-------------------------------------------------------------------------------------------------------------------------------------
# Request a public IP address. The IP address is requested before creating the gateway. 
# You cannot specify the IP address that you want to use; it’s dynamically allocated. You'll use this IP address in the next configuration section. The AllocationMethod must be Dynamic.

#-4-#
$pip = New-AzPublicIpAddress -Name $GWIPName  -ResourceGroupName $RG -Location $Location -AllocationMethod Dynamic
 
#-------------------------------------------------------------------------------------------------------------------------------------
#Create the configuration for your gateway. The gateway configuration defines the subnet and the public IP address to use. In this step, you are specifying the configuration that will be used when you create the gateway. This step does not actually create the gateway object. Use the sample below to create your gateway configuration.

#-5-#
$ipconf = New-AzVirtualNetworkGatewayIpConfig -Name $GWIPconfName -Subnet $subnet -PublicIpAddress $pip
 
#-------------------------------------------------------------------------------------------------------------------------------------
#Create the gateway. In this step, the -GatewayType is especially important. You must use the value ExpressRoute. After running these cmdlets, the gateway can take 45 minutes or more to create.

#-6-#
New-AzVirtualNetworkGateway -Name $GWName -ResourceGroupName $RG -Location $Location -IpConfigurations $ipconf -GatewayType Expressroute -GatewaySku Standard
#-------------------------------------------------------------------------------------------------------------------------------------
 
