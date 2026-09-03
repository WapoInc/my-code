# =====================================================================
#  vWAN Hub / Route Table - clear "Failed" provisioning state
#  RG pinned to: 1  (resource group holding the Global-vWAN hubs)
#  RUN AS A FILE:  ./this.ps1   (don't paste line-by-line)
# =====================================================================

$rg = '1'

# --- Connect & select the subscription holding Global-vWAN ---
Connect-AzAccount
Select-AzSubscription -SubscriptionName "viresent-New-AIRS"

# --- Which hubs + which built-in route table to poke on each ---
$targets = @(
    @{ Hub = 'ZAN-Hub-1'; RouteTable = 'defaultRouteTable' }
    @{ Hub = 'ZAW-Hub-1'; RouteTable = 'noneRouteTable'    }
)

# --- Inventory the hubs in this RG so you can see their state first ---
Write-Host "`n=== Virtual hubs in RG '$rg' ===" -ForegroundColor Cyan
Get-AzVirtualHub -ResourceGroupName $rg |
    Select-Object Name, ResourceGroupName, Location, ProvisioningState |
    Format-Table -AutoSize

# =====================================================================
#  Process each target hub
# =====================================================================
foreach ($t in $targets) {

    Write-Host "`n=== Processing $($t.Hub) in RG '$rg' ===" -ForegroundColor Yellow

    # --- Route table (child of hub -> same RG) ---
    $rt = Get-AzVHubRouteTable -ResourceGroupName $rg -ParentResourceName $t.Hub -Name $t.RouteTable -ErrorAction SilentlyContinue
    if ($rt) { Update-AzVHubRouteTable -InputObject $rt -Debug -Verbose } else { Write-Warning "[$($t.Hub)] route table '$($t.RouteTable)' not retrieved - skipping." }

    # --- Virtual hub (Get/Put no-op) ---
    $hub = Get-AzVirtualHub -ResourceGroupName $rg -Name $t.Hub -ErrorAction SilentlyContinue
    if ($hub) { Update-AzVirtualHub -InputObject $hub -Debug -Verbose } else { Write-Warning "[$($t.Hub)] hub not found in RG '$rg' - skipping." }

    # --- Confirm result ---
    $after = (Get-AzVirtualHub -ResourceGroupName $rg -Name $t.Hub -ErrorAction SilentlyContinue).ProvisioningState
    Write-Host "$($t.Hub) provisioning state now: $after" -ForegroundColor Green
}

Write-Host "`n=== Done ===" -ForegroundColor Green