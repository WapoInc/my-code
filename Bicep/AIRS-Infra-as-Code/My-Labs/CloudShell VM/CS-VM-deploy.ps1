& {
    $ErrorActionPreference = 'Stop'

    function Read-RequiredValue {
        param(
            [Parameter(Mandatory)]
            [string] $Prompt
        )

        do {
            $value = (Read-Host $Prompt).Trim()
        } while ([string]::IsNullOrWhiteSpace($value))

        return $value
    }

    $templateFile = Join-Path $PSScriptRoot 'CS-Ubuntu-VM.bicep'
    if (-not (Test-Path $templateFile)) {
        throw "Bicep template not found: $templateFile"
    }

    $location = Read-Host 'Location [southafricanorth]'
    if ([string]::IsNullOrWhiteSpace($location)) {
        $location = 'southafricanorth'
    }

    $resourceGroupName = Read-RequiredValue 'Resource group name'
    $vnetName = Read-RequiredValue 'VNet name'
    $subnetName = Read-RequiredValue 'Subnet name'
    $vmName = Read-RequiredValue 'VM name'

    $adminUsername = Read-Host 'Admin username [rootadmin]'
    if ([string]::IsNullOrWhiteSpace($adminUsername)) {
        $adminUsername = 'adminroot'
    }

    $securePassword = Read-Host 'Admin password' -AsSecureString
    $adminPassword = [System.Net.NetworkCredential]::new('', $securePassword).Password
    if ([string]::IsNullOrWhiteSpace($adminPassword)) {
        throw 'Admin password cannot be empty.'
    }

    $vmSize = Read-Host 'VM size [Standard_B2s]'
    if ([string]::IsNullOrWhiteSpace($vmSize)) {
        $vmSize = 'Standard_B2s'
    }

    $vnetCidr = Read-Host 'VNet CIDR [10.0.0.0/16]'
    if ([string]::IsNullOrWhiteSpace($vnetCidr)) {
        $vnetCidr = '10.0.0.0/16'
    }

    $subnetCidr = Read-Host 'Subnet CIDR [10.0.1.0/24]'
    if ([string]::IsNullOrWhiteSpace($subnetCidr)) {
        $subnetCidr = '10.0.1.0/24'
    }

    $deploymentName = "ubuntu-vm-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

    Write-Host
    Write-Host 'Deployment settings:'
    Write-Host "  Deployment     : $deploymentName"
    Write-Host "  Location       : $location"
    Write-Host "  Resource group : $resourceGroupName"
    Write-Host "  VNet           : $vnetName ($vnetCidr)"
    Write-Host "  Subnet         : $subnetName ($subnetCidr)"
    Write-Host "  VM             : $vmName ($vmSize)"
    Write-Host "  Admin username : $adminUsername"

    $confirmation = Read-Host 'Deploy these resources? [y/N]'
    if ($confirmation -notmatch '^(?i)y(es)?$') {
        Write-Host 'Deployment cancelled.'
        return
    }

    $deploymentArguments = @(
        'deployment', 'sub', 'create'
        '--name', $deploymentName
        '--location', $location
        '--template-file', $templateFile
        '--parameters'
        "resourceGroupName=$resourceGroupName"
        "location=$location"
        "vnetName=$vnetName"
        "subnetName=$subnetName"
        "vmName=$vmName"
        "adminUsername=$adminUsername"
        "adminPassword=$adminPassword"
        "vmSize=$vmSize"
        "vnetCidr=$vnetCidr"
        "subnetCidr=$subnetCidr"
        '--output', 'json'
    )

    & az @deploymentArguments
    if ($LASTEXITCODE -ne 0) {
        throw "Azure deployment failed with exit code $LASTEXITCODE."
    }

    Write-Host
    Write-Host "Deployment '$deploymentName' completed successfully."
}
