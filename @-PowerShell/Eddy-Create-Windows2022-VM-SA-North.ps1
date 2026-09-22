[CmdletBinding()]
param(
    [string]$ResourceGroupName = 'rg-win2022-san',
    [string]$VMName = 'vm-win2022-san',
    [string]$Location = 'SouthAfricaNorth',
    [string]$VMSize = 'Standard_B2s',
    [string]$VNetName = 'vnet1',
    [string]$SubnetName = 'subnet1',
    [string]$AddressPrefix = '10.10.0.0/24',
    [string]$AdminUsername = 'adminroot'
)

$ErrorActionPreference = 'Stop'

$requiredCommands = @(
    'Get-AzContext',
    'New-AzResourceGroup',
    'New-AzVirtualNetwork',
    'New-AzNetworkSecurityGroup',
    'New-AzPublicIpAddress',
    'New-AzNetworkInterface',
    'New-AzVM'
)

foreach ($command in $requiredCommands) {
    if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
        throw "Required command '$command' was not found. Install the Az PowerShell module first."
    }
}

if (-not (Get-AzContext)) {
    Connect-AzAccount | Out-Null
}

$securePassword = Read-Host "Enter the password for '$AdminUsername'" -AsSecureString
$credential = [pscredential]::new($AdminUsername, $securePassword)

try {
    $publicIp = (Invoke-RestMethod -Uri 'https://api.ipify.org' -TimeoutSec 10).Trim()
    $allowedRdpSource = "$publicIp/32"
}
catch {
    throw 'Unable to determine your public IP address. RDP was not opened. Check internet access and run the script again.'
}

$resourceGroup = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
if (-not $resourceGroup) {
    Write-Host "Creating resource group '$ResourceGroupName' in '$Location'..."
    $resourceGroup = New-AzResourceGroup -Name $ResourceGroupName -Location $Location
}

if (Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -ErrorAction SilentlyContinue) {
    throw "VM '$VMName' already exists in resource group '$ResourceGroupName'."
}

$subnetConfig = New-AzVirtualNetworkSubnetConfig `
    -Name $SubnetName `
    -AddressPrefix $AddressPrefix

$vnet = Get-AzVirtualNetwork -ResourceGroupName $ResourceGroupName -Name $VNetName -ErrorAction SilentlyContinue
if (-not $vnet) {
    Write-Host "Creating virtual network '$VNetName' and subnet '$SubnetName'..."
    $vnet = New-AzVirtualNetwork `
        -Name $VNetName `
        -ResourceGroupName $ResourceGroupName `
        -Location $Location `
        -AddressPrefix $AddressPrefix `
        -Subnet $subnetConfig
}

$subnet = $vnet.Subnets | Where-Object Name -EQ $SubnetName
if (-not $subnet) {
    throw "VNet '$VNetName' exists but does not contain subnet '$SubnetName'."
}

$nsgName = "$VMName-nsg"
$publicIpName = "$VMName-pip"
$nicName = "$VMName-nic"

foreach ($resourceName in @($nsgName, $publicIpName, $nicName)) {
    $existingResource = Get-AzResource -ResourceGroupName $ResourceGroupName -Name $resourceName -ErrorAction SilentlyContinue
    if ($existingResource) {
        throw "Resource '$resourceName' already exists. Remove it or choose a different VMName."
    }
}

$rdpRule = New-AzNetworkSecurityRuleConfig `
    -Name 'Allow-RDP-From-Current-IP' `
    -Description "Allow RDP only from $allowedRdpSource" `
    -Protocol Tcp `
    -Direction Inbound `
    -Priority 1000 `
    -SourceAddressPrefix $allowedRdpSource `
    -SourcePortRange '*' `
    -DestinationAddressPrefix '*' `
    -DestinationPortRange 3389 `
    -Access Allow

Write-Host "Creating NSG with RDP restricted to '$allowedRdpSource'..."
$nsg = New-AzNetworkSecurityGroup `
    -Name $nsgName `
    -ResourceGroupName $ResourceGroupName `
    -Location $Location `
    -SecurityRules $rdpRule

$vmPublicIp = New-AzPublicIpAddress `
    -Name $publicIpName `
    -ResourceGroupName $ResourceGroupName `
    -Location $Location `
    -AllocationMethod Static `
    -Sku Standard

$nic = New-AzNetworkInterface `
    -Name $nicName `
    -ResourceGroupName $ResourceGroupName `
    -Location $Location `
    -SubnetId $subnet.Id `
    -PublicIpAddressId $vmPublicIp.Id `
    -NetworkSecurityGroupId $nsg.Id

$vmConfig = New-AzVMConfig `
    -VMName $VMName `
    -VMSize $VMSize `
    -SecurityType TrustedLaunch

$vmConfig = Set-AzVMOperatingSystem `
    -VM $vmConfig `
    -Windows `
    -ComputerName $VMName `
    -Credential $credential `
    -ProvisionVMAgent `
    -EnableAutoUpdate

$vmConfig = Set-AzVMSourceImage `
    -VM $vmConfig `
    -PublisherName 'MicrosoftWindowsServer' `
    -Offer 'WindowsServer' `
    -Skus '2022-datacenter-azure-edition' `
    -Version 'latest'

$vmConfig = Set-AzVMOSDisk `
    -VM $vmConfig `
    -CreateOption FromImage `
    -StorageAccountType StandardSSD_LRS

$vmConfig = Add-AzVMNetworkInterface -VM $vmConfig -Id $nic.Id

Write-Host "Creating VM '$VMName' with size '$VMSize'. This can take several minutes..."
New-AzVM `
    -ResourceGroupName $ResourceGroupName `
    -Location $Location `
    -VM $vmConfig

$vmPublicIp = Get-AzPublicIpAddress -ResourceGroupName $ResourceGroupName -Name $publicIpName

Write-Host ''
Write-Host "VM created successfully."
Write-Host "Public IP: $($vmPublicIp.IpAddress)"
Write-Host "RDP: mstsc /v:$($vmPublicIp.IpAddress)"