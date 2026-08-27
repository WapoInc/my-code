$ErrorActionPreference = 'Stop'

##############################################################################
# Create a Windows Server 2022 VM in the CURRENT Cloud Shell tenant/subscription
##############################################################################

function Invoke-AzCli {
    param(
        [Parameter(Mandatory)]
        [string[]] $Arguments
    )

    & az @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI command failed: az $($Arguments -join ' ')"
    }
}

$account = Invoke-AzCli -Arguments @('account', 'show', '--output', 'json') | ConvertFrom-Json
Write-Host "Signed in as : $($account.user.name)"
Write-Host "Tenant       : $($account.tenantId)"
Write-Host "Subscription : $($account.name)  ($($account.id))"
Write-Host

$confirmation = Read-Host 'Continue in THIS subscription? (y/n)'
if ($confirmation -notin @('y', 'Y')) {
    Write-Host "Aborted. Run 'az account set --subscription <name-or-id>' first."
    exit 1
}
Write-Host

$location = Read-Host 'Azure region [southafricanorth]'
if ([string]::IsNullOrWhiteSpace($location)) {
    $location = 'southafricanorth'
}

$resourceGroup = Read-Host 'Resource group name'
$vnet = Read-Host 'VNet name'
$subnet = Read-Host 'Subnet name'
$vmName = Read-Host 'VM name'
$adminUser = 'adminroot'
$adminPassword = 'P@ssw0rd123!'
Write-Host

$vmSize = Read-Host 'VM size [Standard_B2s]'
if ([string]::IsNullOrWhiteSpace($vmSize)) {
    $vmSize = 'Standard_B2s'
}

$vnetCidr = Read-Host 'VNet address space (only used if VNet is new) [10.0.0.0/16]'
if ([string]::IsNullOrWhiteSpace($vnetCidr)) {
    $vnetCidr = '10.0.0.0/16'
}

$subnetCidr = Read-Host 'Subnet prefix (only used if subnet is new) [10.0.1.0/24]'
if ([string]::IsNullOrWhiteSpace($subnetCidr)) {
    $subnetCidr = '10.0.1.0/24'
}

$windowsImage = 'MicrosoftWindowsServer:WindowsServer:2022-datacenter-azure-edition:latest'

$resourceGroupExists = Invoke-AzCli -Arguments @(
    'group', 'exists',
    '--name', $resourceGroup,
    '--output', 'tsv'
)

if ($resourceGroupExists -eq 'false') {
    Write-Host "Creating resource group '$resourceGroup' in '$location'..."
    Invoke-AzCli -Arguments @(
        'group', 'create',
        '--name', $resourceGroup,
        '--location', $location,
        '--output', 'none'
    )
}
else {
    Write-Host "Resource group '$resourceGroup' already exists."
}

& az network vnet show --resource-group $resourceGroup --name $vnet --output none 2>$null
$vnetExists = $LASTEXITCODE -eq 0

if (-not $vnetExists) {
    Write-Host "Creating VNet '$vnet' ($vnetCidr) with subnet '$subnet' ($subnetCidr)..."
    Invoke-AzCli -Arguments @(
        'network', 'vnet', 'create',
        '--resource-group', $resourceGroup,
        '--name', $vnet,
        '--location', $location,
        '--address-prefixes', $vnetCidr,
        '--subnet-name', $subnet,
        '--subnet-prefixes', $subnetCidr,
        '--output', 'none'
    )
}
else {
    Write-Host "VNet '$vnet' exists."
    & az network vnet subnet show --resource-group $resourceGroup --vnet-name $vnet --name $subnet --output none 2>$null
    $subnetExists = $LASTEXITCODE -eq 0

    if (-not $subnetExists) {
        Write-Host "Creating subnet '$subnet' ($subnetCidr) in existing VNet..."
        Invoke-AzCli -Arguments @(
            'network', 'vnet', 'subnet', 'create',
            '--resource-group', $resourceGroup,
            '--vnet-name', $vnet,
            '--name', $subnet,
            '--address-prefixes', $subnetCidr,
            '--output', 'none'
        )
    }
    else {
        Write-Host "Subnet '$subnet' exists."
    }
}

Write-Host
Write-Host "Creating VM '$vmName' ($vmSize, Windows Server 2022)..."
Invoke-AzCli -Arguments @(
    'vm', 'create',
    '--resource-group', $resourceGroup,
    '--name', $vmName,
    '--location', $location,
    '--image', $windowsImage,
    '--size', $vmSize,
    '--vnet-name', $vnet,
    '--subnet', $subnet,
    '--authentication-type', 'password',
    '--admin-username', $adminUser,
    '--admin-password', $adminPassword,
    '--public-ip-sku', 'Standard',
    '--output', 'json',
    '--query', '{PublicIP:publicIpAddress, PrivateIP:privateIpAddress, PowerState:powerState}'
)

Write-Host
Write-Host "Done. Connect with RDP using username: $adminUser"
Write-Host 'If RDP is blocked, open port 3389:'
Write-Host "  az vm open-port --resource-group `"$resourceGroup`" --name `"$vmName`" --port 3389"