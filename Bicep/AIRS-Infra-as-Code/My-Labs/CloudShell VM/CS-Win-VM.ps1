& {
$ErrorActionPreference = 'Stop'

##############################################################################
# Create a Windows Server 2022 VM in the CURRENT Cloud Shell tenant/subscription
##############################################################################

function Read-ValidatedName {
    param(
        [Parameter(Mandatory)]
        [string] $Prompt,

        [Parameter(Mandatory)]
        [string] $Pattern,

        [Parameter(Mandatory)]
        [string] $Requirements
    )

    while ($true) {
        $value = (Read-Host $Prompt).Trim()
        if (-not [string]::IsNullOrWhiteSpace($value) -and $value -match $Pattern) {
            return $value
        }

        Write-Warning "Invalid value. $Requirements"
    }
}

# --- Enter all deployment values here ---------------------------------------
$subscriptionId = '' # Optional. Leave empty to use the current subscription.
$location = 'southafricanorth'
$resourceGroup = Read-ValidatedName -Prompt 'Resource group name' `
    -Pattern '^[A-Za-z0-9_.()-]{1,90}$' `
    -Requirements 'Use 1-90 letters, numbers, underscores, periods, parentheses, or hyphens.'
$vnet = Read-ValidatedName -Prompt 'VNet name' `
    -Pattern '^[A-Za-z0-9][A-Za-z0-9_.-]{0,62}[A-Za-z0-9_]$' `
    -Requirements 'Use 2-64 letters, numbers, underscores, periods, or hyphens; start with a letter or number.'
$subnet = Read-ValidatedName -Prompt 'Subnet name' `
    -Pattern '^[A-Za-z0-9][A-Za-z0-9_.-]{0,78}[A-Za-z0-9_]$' `
    -Requirements 'Use 2-80 letters, numbers, underscores, periods, or hyphens; start with a letter or number.'
$vmName = Read-ValidatedName -Prompt 'VM name' `
    -Pattern '^(?![0-9]+$)[A-Za-z0-9][A-Za-z0-9-]{0,14}$' `
    -Requirements 'Use 1-15 letters, numbers, or hyphens; do not use only numbers.'
$adminUser = 'adminroot'
$adminPassword = 'P@ssw0rd123!'
$vmSize = 'Standard_B2s'
$vnetCidr = '10.0.0.0/16' # Used only when creating a VNet.
$subnetCidr = '10.0.1.0/24' # Used only when creating a subnet.
$windowsImage = 'MicrosoftWindowsServer:WindowsServer:2022-datacenter-azure-edition:latest'

# --- Deployment starts here -------------------------------------------------

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

if (-not [string]::IsNullOrWhiteSpace($subscriptionId)) {
    Invoke-AzCli -Arguments @(
        'account', 'set',
        '--subscription', $subscriptionId
    )
}

$account = Invoke-AzCli -Arguments @('account', 'show', '--output', 'json') | ConvertFrom-Json
Write-Host "Signed in as : $($account.user.name)"
Write-Host "Tenant       : $($account.tenantId)"
Write-Host "Subscription : $($account.name)  ($($account.id))"
Write-Host

Write-Host 'Deployment settings:'
Write-Host "  Location       : $location"
Write-Host "  Resource group : $resourceGroup"
Write-Host "  VNet           : $vnet"
Write-Host "  Subnet         : $subnet"
Write-Host "  VM             : $vmName"
Write-Host '  Public IP      : None'
$confirmation = Read-Host 'Continue? [y/N]'
if ($confirmation -notmatch '^(?i)y(es)?$') {
    Write-Host 'Deployment cancelled.'
    exit 0
}
Write-Host

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
    $vnetDetails = Invoke-AzCli -Arguments @(
        'network', 'vnet', 'show',
        '--resource-group', $resourceGroup,
        '--name', $vnet,
        '--output', 'json'
    ) | ConvertFrom-Json
    $currentVnetCidrs = @($vnetDetails.addressSpace.addressPrefixes)
    $currentVnetCidrDisplay = $currentVnetCidrs -join ', '
    Write-Host "VNet '$vnet' exists with CIDR: $currentVnetCidrDisplay"

    $requestedVnetCidr = Read-Host "New VNet CIDR [$currentVnetCidrDisplay] (press Enter to keep current)"
    if ([string]::IsNullOrWhiteSpace($requestedVnetCidr)) {
        $vnetCidrs = $currentVnetCidrs
    }
    else {
        $vnetCidrs = @($requestedVnetCidr.Split(',').Trim() | Where-Object { $_ })
    }
    $vnetCidrChanged = (Compare-Object $currentVnetCidrs $vnetCidrs).Count -gt 0

    & az network vnet subnet show --resource-group $resourceGroup --vnet-name $vnet --name $subnet --output none 2>$null
    $subnetExists = $LASTEXITCODE -eq 0

    if (-not $subnetExists) {
        if ($vnetCidrChanged) {
            Invoke-AzCli -Arguments (@(
                'network', 'vnet', 'update',
                '--resource-group', $resourceGroup,
                '--name', $vnet,
                '--address-prefixes'
            ) + $vnetCidrs + @('--output', 'none'))
            Write-Host "VNet '$vnet' CIDR updated to: $($vnetCidrs -join ', ')"
        }

        do {
            $subnetCidr = Read-Host "Subnet '$subnet' does not exist. Enter a CIDR within VNet range $($vnetCidrs -join ', ')"
        } while ([string]::IsNullOrWhiteSpace($subnetCidr))

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
        $subnetDetails = Invoke-AzCli -Arguments @(
            'network', 'vnet', 'subnet', 'show',
            '--resource-group', $resourceGroup,
            '--vnet-name', $vnet,
            '--name', $subnet,
            '--output', 'json'
        ) | ConvertFrom-Json
        $currentSubnetCidrs = if ($subnetDetails.addressPrefixes) {
            @($subnetDetails.addressPrefixes)
        }
        else {
            @($subnetDetails.addressPrefix)
        }
        $currentSubnetCidrDisplay = $currentSubnetCidrs -join ', '
        Write-Host "Subnet '$subnet' exists with CIDR: $currentSubnetCidrDisplay"

        $useCurrentSubnetCidr = Read-Host 'Use the current subnet CIDR? [Y/n]'
        if ([string]::IsNullOrWhiteSpace($useCurrentSubnetCidr) -or $useCurrentSubnetCidr -match '^(?i)y(es)?$') {
            $subnetCidrs = $currentSubnetCidrs
        }
        else {
            do {
                $requestedSubnetCidr = Read-Host "New subnet CIDR (must be within VNet range $($vnetCidrs -join ', '))"
            } while ([string]::IsNullOrWhiteSpace($requestedSubnetCidr))
            $subnetCidrs = @($requestedSubnetCidr.Split(',').Trim() | Where-Object { $_ })
        }
        $subnetCidrChanged = (Compare-Object $currentSubnetCidrs $subnetCidrs).Count -gt 0

        if ($vnetCidrChanged -and $subnetCidrChanged) {
            $transitionVnetCidrs = @($currentVnetCidrs + $vnetCidrs | Select-Object -Unique)
            Invoke-AzCli -Arguments (@(
                'network', 'vnet', 'update',
                '--resource-group', $resourceGroup,
                '--name', $vnet,
                '--address-prefixes'
            ) + $transitionVnetCidrs + @('--output', 'none'))
        }
        elseif ($vnetCidrChanged) {
            Invoke-AzCli -Arguments (@(
                'network', 'vnet', 'update',
                '--resource-group', $resourceGroup,
                '--name', $vnet,
                '--address-prefixes'
            ) + $vnetCidrs + @('--output', 'none'))
        }

        if ($subnetCidrChanged) {
            Invoke-AzCli -Arguments (@(
                'network', 'vnet', 'subnet', 'update',
                '--resource-group', $resourceGroup,
                '--vnet-name', $vnet,
                '--name', $subnet,
                '--address-prefixes'
            ) + $subnetCidrs + @('--output', 'none'))
            Write-Host "Subnet '$subnet' CIDR updated to: $($subnetCidrs -join ', ')"
        }

        if ($vnetCidrChanged -and $subnetCidrChanged) {
            Invoke-AzCli -Arguments (@(
                'network', 'vnet', 'update',
                '--resource-group', $resourceGroup,
                '--name', $vnet,
                '--address-prefixes'
            ) + $vnetCidrs + @('--output', 'none'))
        }

        if ($vnetCidrChanged) {
            Write-Host "VNet '$vnet' CIDR updated to: $($vnetCidrs -join ', ')"
        }
    }
}

Write-Host
Write-Host "Creating VM '$vmName' ($vmSize, Windows Server 2022)..."
$vmCreateArguments = @(
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
    '--public-ip-address', '',
    '--output', 'json',
    '--query', '{PrivateIP:privateIpAddress, PowerState:powerState}'
)
& az @vmCreateArguments
if ($LASTEXITCODE -ne 0) {
    throw "Azure CLI command failed: az $($vmCreateArguments -join ' ')"
}

Write-Host
Write-Host "Done. VM '$vmName' has no public IP address."
Write-Host "Connect over the private network with RDP using username: $adminUser"
}