## Variables

$Location           = 'SouthAfricaNorth'
$ResourceGroup      = 'RG1'
$VNET_Name          = 'MyVNET-2'




New-AzResourceGroup -Name $ResourceGroup -Location $Location

$gatewaySubnet      = New-AzVirtualNetworkSubnetConfig -Name GatewaySubnet  -AddressPrefix "10.0.0.0/27"
$frontendSubnet     = New-AzVirtualNetworkSubnetConfig -Name Frontend-SubNet -AddressPrefix "10.0.1.0/24"
$backendSubnet      = New-AzVirtualNetworkSubnetConfig -Name Backend-SubNet  -AddressPrefix "10.0.2.0/24"
$midSubnet          = New-AzVirtualNetworkSubnetConfig -Name Mid-SubNet  -AddressPrefix "10.0.3.0/24"




New-AzVirtualNetwork `
     -Name $VNET_Name `
     -ResourceGroupName $ResourceGroup `
     -Location $Location `
     -AddressPrefix "10.0.0.0/22" `
     -Subnet $frontendSubnet,$backendSubnet,$midSubnet,$gatewaySubnet


