# ExpressRoute Gateway
Get-AzExpressRouteGatewayConnection -ResourceGroupName za-east-vdc -ExpressRouteGatewayName 2-ZAN-ER-GW-Migration-Test-for-Shoppies


# Variables
$RG          = "za-east-vdc"
$GatewayName = "2-ZAN-ER-GW-Migration-Test-for-Shoppies"

$RG          = "er-ltsa-rg"
$GatewayName = "ER-GateWay-SA-North-Standard"

# List all connections referencing this gateway
$gw   = Get-AzVirtualNetworkGateway -ResourceGroupName $RG -Name $GatewayName
$cons = Get-AzVirtualNetworkGatewayConnection -ResourceGroupName $RG |
          Where-Object {
            $_.VirtualNetworkGateway1.Id -eq $gw.Id -or
            ($_.VirtualNetworkGateway2 -and $_.VirtualNetworkGateway2.Id -eq $gw.Id)
          }

$cons | Select Name, ConnectionType, ProvisioningState,
    @{n='PeerCircuitId';e={$_.Peer.Id}} | Format-Table -AutoSize

# Count ExpressRoute connections
($cons | Where-Object ConnectionType -eq 'ExpressRoute').Count

# Show one connection (replace NAME)
Get-AzVirtualNetworkGatewayConnection -Name "ER-Connection-to-ER-GW-to-ZA-North" -ResourceGroupName $RG | Format-List *

# Delete a connection (confirm)
Remove-AzVirtualNetworkGatewayConnection -Name "REPLACE-CONNECTION-NAME" -ResourceGroupName $RG -Force

# Learned routes (full list)
$routes = Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayName $GatewayName
$routes | Select Network, NextHop, AsPath, Origin, Weight | Sort-Object Network | Format-Table -AutoSize

# Count learned routes
$routes.Count

# Filter by prefix
$routes | Where-Object Network -eq "10.10.0.0/16"

# Filter by ASN in AS Path
$routes | Where-Object AsPath -match "\b65522\b"

# Export learned routes
$routes | Sort-Object Network | Export-Csv ".\\er-learned-routes.csv" -NoTypeInformation

# Quick one-liners
(Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayName $GatewayName).Count
Get-AzVirtualNetworkGatewayLearnedRoute -ResourceGroupName $RG -VirtualNetworkGatewayName $GatewayName |
  Where-Object { $_.Network -eq "10.10.0.0/16" }

# OPTIONAL: Map peer circuit details (if Peer.Id present)
$circuits = foreach ($c in ($cons | Where-Object ConnectionType -eq 'ExpressRoute')) {
  $peerId = $c.Peer.Id
  if ($peerId) {
    $parts = $peerId -split '/'
    $circuitRg = $parts[$parts.IndexOf('resourceGroups')+1]
    $circuitName = $parts[-1]
    $ckt = Get-AzExpressRouteCircuit -ResourceGroupName $circuitRg -Name $circuitName -ErrorAction SilentlyContinue
    if ($ckt) {
      [PSCustomObject]@{
        Connection   = $c.Name
        Circuit      = $ckt.Name
        SkuTier      = $ckt.Sku.Tier
        SkuFamily    = $ckt.Sku.Family
        Provisioning = $ckt.ProvisioningState
        ServiceKey   = $ckt.ServiceKey
      }
    }
  }
}
$circuits | Format-Table -AutoSize