# =====================================================================
#  Azure Virtual WAN - hub route inventory
#  Lists configured routes in every hub route table and effective routes
#  in each hub's defaultRouteTable.
# =====================================================================

[CmdletBinding()]
param(
    [string]$ResourceGroupName = 'Global-vWAN-PoC',
    [string]$SubscriptionName = 'viresent-New-AIRS'
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Module -ListAvailable -Name Az.Network)) {
    throw "The Az.Network module is required. Install it with: Install-Module Az.Network -Scope CurrentUser"
}

function Get-NextHopName {
    param([AllowNull()][object]$NextHop)

    @($NextHop) | ForEach-Object {
        $value = ([string]$_).Trim().TrimEnd('/')
        if ($value) {
            ($value -split '/')[-1]
        }
    }
}

try {
    $null = Get-AzContext
    Select-AzSubscription -SubscriptionName $SubscriptionName | Out-Null
} catch {
    throw "Unable to select subscription '$SubscriptionName'. Run Connect-AzAccount and try again. $($_.Exception.Message)"
}

try {
    $hubs = @(Get-AzVirtualHub -ResourceGroupName $ResourceGroupName)
} catch {
    throw "Unable to list virtual hubs in resource group '$ResourceGroupName'. $($_.Exception.Message)"
}

if ($hubs.Count -eq 0) {
    Write-Warning "No virtual hubs were found in resource group '$ResourceGroupName'."
    return
}

$effectiveRouteRows = foreach ($hub in $hubs) {
    try {
        $routeTables = @(Get-AzVHubRouteTable `
            -VirtualHub $hub)
    } catch {
        Write-Warning "[$($hub.Name)] Unable to list hub route tables. $($_.Exception.Message)"
        continue
    }

    $defaultRouteTable = $routeTables |
        Where-Object Name -EQ 'defaultRouteTable' |
        Select-Object -First 1

    if (-not $defaultRouteTable) {
        Write-Warning "[$($hub.Name)] defaultRouteTable was not found."
        continue
    }

    try {
        $effectiveResult = Get-AzVHubEffectiveRoute `
            -VirtualHubObject $hub `
            -ResourceId $defaultRouteTable.Id `
            -VirtualWanResourceType 'RouteTable'

        $effectiveRoutes = $effectiveResult.Value
        if ($effectiveRoutes -is [string]) {
            $effectiveRoutes = $effectiveRoutes | ConvertFrom-Json
        }

        foreach ($route in @($effectiveRoutes)) {
            [pscustomobject]@{
                Hub             = $hub.Name
                RouteTable      = $defaultRouteTable.Name
                AddressPrefixes = @($route.AddressPrefixes) -join ', '
                NextHopType     = $route.NextHopType
                NextHop         = @(Get-NextHopName $route.NextHops) -join ', '
            }
        }
    } catch {
        Write-Warning "[$($hub.Name)] Unable to retrieve effective routes. $($_.Exception.Message)"
    }
}

if ($effectiveRouteRows) {
    foreach ($hubName in @($effectiveRouteRows.Hub | Sort-Object -Unique)) {
        Write-Host "`n=== Hub: $hubName - defaultRouteTable ===" -ForegroundColor Cyan
        $effectiveRouteRows |
            Where-Object Hub -EQ $hubName |
            Sort-Object AddressPrefixes |
            Select-Object AddressPrefixes, NextHopType, NextHop |
            Format-Table -AutoSize -Wrap |
            Out-Host
    }
} else {
    Write-Host 'No effective routes returned.'
}