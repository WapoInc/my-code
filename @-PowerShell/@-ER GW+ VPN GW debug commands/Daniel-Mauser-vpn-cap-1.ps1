#======================================================================================================================================================================================

Param(
    [Parameter(Mandatory=$true,
    HelpMessage="Add ")]
    [String]
    $VPNGWName,

    [Parameter(Mandatory=$true,
    HelpMessage="Add VPN Gateway Resource Group Name")]
    [String]
    $VPNGWRG,

    [Parameter(Mandatory=$true,
    HelpMessage="Add Storage Account Name")]
    [String]
    $StgName,

    [Parameter(Mandatory=$true,
    HelpMessage="Add Storage Account Resource Group Name")]
    [String]
    $StgRG,

    [Parameter(Mandatory=$true,
    HelpMessage="Add Storage Account blob container Name")]
    [String]
    $StgContainerName
)
#======================================================================================================================================================================================

Set-AzContext -Subscription "0cfd0d2a-2b38-4c93-ba14-cf79185bc683"

$VPNGWName = "ZA-East-vDC-VPN-GW"
$VPNGWRG = "ZA-East-vDC"
$StgName = "vpngwandconnection"
$StgRG     = "ZA-East-vDC"
$StgContainerName = "er-ltsa-rg"


# For a new Cx check their Subscription ID and use it as below
#DRLLRD 
Az Login
# You will see a list of all Subscriptions your Login has accesss to

Set-AzContext -Subscription "2fe3ae57-6bdf-4570-96d6-9b23b808d4a6"
Get-AzContext

$VPNGWName = "LTSA-VPN-GateWay-SA-North"
$VPNGWRG = "er-ltsa-rg"
$StgName = "vpngwandconnection"
$StgRG     = "ZA-East-vDC"
$StgContainerName = "vpngwconncapture"

#======================================================================================================================================================================================
# Variables that can be adjusted based in your needs.
# Filter1 gets inner and outer IPSec Tunnel traffic (Default filter used by this script).
$Filter1 = "{`"TracingFlags`": 11,`"MaxPacketBufferSize`": 120,`"MaxFileSize`": 500,`"Filters`" :[{`"CaptureSingleDirectionTrafficOnly`": false}]}" 
# Filter2 shows how to filter between IPs or Subnets.
# Use this Filter 2 to be more specific on an IP
$Filter2 = "{`"TracingFlags`": 11,`"MaxPacketBufferSize`": 120,`"MaxFileSize`": 500,`"Filters`" :[{`"SourceSubnets`":[`"192.168.2.0/24`"],`"DestinationSubnets`":[`"10.20.1.0/24`"],`"CaptureSingleDirectionTrafficOnly`": false}]}" # This filter gets inner and outer IPSec Tunnel traffic.

#======================================================================================================================================================================================
# BuP Filter2
#$Filter2 = "{`"TracingFlags`": 11,`"MaxPacketBufferSize`": 120,`"MaxFileSize`": 500,`"Filters`" :[{`"SourceSubnets`":[`"10.60.4.4/32`",`"10.200.1.5/32`"],`"DestinationSubnets`":[`"10.60.4.4/32`",`"10.200.1.5/32`"],`"CaptureSingleDirectionTrafficOnly`": false}]}" # This filter gets inner and outer IPSec Tunnel traffic.
#======================================================================================================================================================================================


<# Few notes about filters: 
1) MaxPacketBufferSize it takes first 120 bytes. You can change it to 1500 to get full packet size in case you need to investigate the payload.
2) MaxFileSize is 500 MB.
#>
$startTime = Get-Date
$EndTime = $startTime.AddDays(1)
$ctx = (Get-AzStorageAccount -Name $StgName -ResourceGroupName $StgRG).Context
$SAStokenURL = New-AzStorageContainerSASToken  -Context $ctx -Container $StgContainerName -Permission rwd -ExpiryTime $EndTime -FullUri

# Get full VPN Gateway Capture
## Start Packet Capture
Write-Host ""
Write-Host ""

Write-Host ""
Write-Host "Please wait, starting VPN Gateway packet capture..." -ForegroundColor Yellow
Start-AzVirtualnetworkGatewayPacketCapture -ResourceGroupName $VPNGWRG -Name $VPNGWName -FilterData $Filter1
## Stop Packet Capture
Write-Host -NoNewLine 'Reproduce your issue and press any key to stop to capture...' -ForegroundColor Yellow;
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
Write-Host ""
Write-Host "Please wait, stopping VPN Gateway packet capture..." -ForegroundColor Red

Stop-AzVirtualnetworkGatewayPacketCapture -ResourceGroupName $VPNGWRG -Name $VPNGWName -SasUrl $SAStokenURL

## Retrieve your Packet Captures
Write-Host "Retrieve packet captures using Storage Explorer over:" -ForegroundColor Yellow
Write-Host "Storage account:" $StgName
Write-Host "Blob container :" $StgContainerName

#======================================================================================================================================================================================
