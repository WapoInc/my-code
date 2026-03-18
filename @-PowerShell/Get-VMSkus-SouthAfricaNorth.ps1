###################################################################
#                                                                 #
# Purpose: List all VM SKU sizes available in SouthAfricaNorth   #
#          with optional filter for Nutanix (NC2 on Azure)        #
# Language: PowerShell                                            #
###################################################################

Param
(
    [Parameter(Mandatory=$true)][string]$SubscriptionID,
    [Parameter(Mandatory=$false)][string]$Location = "SouthAfricaNorth",
    [Parameter(Mandatory=$false)][switch]$NutanixOnly
)

# Set subscription context
$subscription = Get-AzSubscription -SubscriptionId $SubscriptionID
Set-AzContext -SubscriptionObject $subscription

if ($NutanixOnly) {
    Write-Host "`nFetching Nutanix-compatible VM SKUs (Standard_AN family) for region: $Location ..." -ForegroundColor Cyan
    Write-Host "Nutanix Cloud Clusters (NC2) on Azure requires Standard_AN series bare metal instances.`n" -ForegroundColor DarkCyan
} else {
    Write-Host "`nFetching VM SKU sizes for region: $Location ..." -ForegroundColor Cyan
}

$skus = Get-AzComputeResourceSku -Location $Location |
    Where-Object {
        $_.ResourceType -eq "virtualMachines" -and
        (!$NutanixOnly -or $_.Name -like "Standard_AN*")
    } |
    Select-Object -Property `
        @{Name="Name";          Expression={$_.Name}},
        @{Name="Tier";          Expression={$_.Tier}},
        @{Name="Family";        Expression={$_.Family}},
        @{Name="vCPUs";         Expression={($_.Capabilities | Where-Object {$_.Name -eq "vCPUs"}).Value}},
        @{Name="MemoryGB";      Expression={($_.Capabilities | Where-Object {$_.Name -eq "MemoryGB"}).Value}},
        @{Name="MaxDataDisks";  Expression={($_.Capabilities | Where-Object {$_.Name -eq "MaxDataDiskCount"}).Value}},
        @{Name="NvmeDiskCount"; Expression={($_.Capabilities | Where-Object {$_.Name -eq "NvmeDiskCount"}).Value}},
        @{Name="Restrictions";  Expression={if ($_.Restrictions) { ($_.Restrictions | ForEach-Object { $_.ReasonCode }) -join "; " } else { "None" }}} |
    Sort-Object Family, Name

# Display results
$skus | Format-Table -AutoSize

Write-Host "`nTotal SKUs found: $($skus.Count)" -ForegroundColor Green

if ($NutanixOnly -and $skus.Count -eq 0) {
    Write-Host "No Standard_AN SKUs found in $Location. NC2 on Azure may not be available in this region." -ForegroundColor Yellow
}

# Export to CSV
$Suffix = if ($NutanixOnly) { "Nutanix" } else { "All" }
$ExportPath = ".\VMSkus-$Location-$Suffix-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"
$skus | Export-Csv -Path $ExportPath -NoTypeInformation
Write-Host "Results exported to: $ExportPath" -ForegroundColor Yellow
