# -------------------------------------------------------------------------------------------------
#  <copyright file="SetRegistryForTrustedSites.ps1" company="Microsoft">
#      Copyright (c) Microsoft Corporation. All rights reserved.
#  </copyright>
#
#  Description: This script adds URLs used by Azure Migrate in trusted zone.

#  Version: 6.0.0.0

#  Requirements: 
#       PowerShell 4.0+
# -------------------------------------------------------------------------------------------------

[CmdletBinding(DefaultParameterSetName="None")]
param(
    [Parameter(Mandatory=$false)]
    [boolean]$LaunchApplication = $true
    )

<#
.Synopsis  
  Creating registry keys for trusted sites.
  
#>

$InternetSettingsRegistryHive = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings";
$TrustedSitesEscDomainsRegistryHive = $InternetSettingsRegistryHive + "\ZoneMap\EscDomains";
$TrustedSitesDomainsRegistryHive = $InternetSettingsRegistryHive + "\ZoneMap\Domains";
$InternetExplorerRegistryHive = "HKCU:\Software\Microsoft\Internet Explorer\New Windows";
$regKeyIEAllow = $InternetExplorerRegistryHive + "\Allow";
$regKeyEscBlankDomain = $TrustedSitesEscDomainsRegistryHive + "\blank";
$regKeyBlankDomain = $TrustedSitesDomainsRegistryHive + "\blank";
$machineHostName = (Get-WmiObject win32_computersystem).DNSHostName
$LogFileDir = "$env:SystemRoot\Setup"
$logName = $LogFileDir + "\SetRegistry-" + [DateTime]::Now.ToString("yyyy-MM-dd-HH-mm-ss") + ".log"
$DefaultURL = "https://" + $machineHostName + ":44368"

## This routine writes the output string to the console and also to a log file.
function Log-Info([string] $OutputText)
{
    $OutputText | %{ Write-Output $_; Out-File -filepath $logName -inputobject $_ -append -encoding "ASCII" }
}

## This routine writes the output string to the console and also to a log file.
function Log-Error([string] $OutputText)
{
    $OutputText | %{ Write-Error $_; Out-File -filepath $logName -inputobject $_ -append -encoding "ASCII" }
}

<#
.SYNOPSIS
    Adds Trusted Local domains to registry.
#>
function AddTrustedLocalDomains
{
    Log-Info "Adding trusted local domains."

    $machineName = (Get-WmiObject win32_computersystem).DNSHostName
    $domainName = (Get-WmiObject win32_computersystem).Domain
    $fqdn = $machineName+"."+$domainName
    
    Log-Info "machineName = $machineName"
    Log-Info "domainName = $domainName"
    Log-Info "fqdn = $fqdn"
    
    # List of trusted local domains.
    $trustedLocalDomains = New-Object System.Collections.Generic.List[string]
    $trustedLocalDomains.Add("localhost");
    $trustedLocalDomains.Add($machineName);
    $trustedLocalDomains.Add($fqdn);

    # Create trusted local domain registry keys.
    foreach ($domain in $trustedLocalDomains)
    {
        New-ItemProperty -Path $regKeyIEAllow -Name $domain -Value 0 -Force

        $regKeyEscDomain = $TrustedSitesEscDomainsRegistryHive + "\" + $domain
        $regKeyDomain = $TrustedSitesDomainsRegistryHive + "\" + $domain
        foreach ($regKey in $regKeyEscDomain,$regKeyDomain)
        {
            if ( -not (Test-Path $regKey))
            {
                Log-Info "Creating $regKey"
                New-Item -Path $regKey -Force
            }
            
            # Add https key and setting its value to 1.
            New-ItemProperty -Path $regKey -Name "https" -Value 1 -Force
        }
    }
}

<#
.SYNOPSIS
    Adds Trusted domains to registry.
#>
function AddTrustedDomains
{
    Log-Info "Adding trusted domains."
    
    # List of trusted domains.
    $trustedDomains = New-Object System.Collections.Generic.List[string]
    $trustedDomains.Add("*.live.com")
    $trustedDomains.Add("*.microsoft.com");
    $trustedDomains.Add("*.microsoftonline.com");
    $trustedDomains.Add("*.microsoftonline-p.com");
    $trustedDomains.Add("*.azure.net");
    $trustedDomains.Add("*.azure.com");
    $trustedDomains.Add("*.msecnd.net");
    $trustedDomains.Add("*.windows.net");
    $trustedDomains.Add("*.gfx.ms");
    $trustedDomains.Add("*.azuremigrate.blob.core.windows.net");
    $trustedDomains.Add("*.microsoft.ca1.qualtrics.com");
    $trustedDomains.Add("*.msftauth.net");
    $trustedDomains.Add("*.msauth.net");
    $trustedDomains.Add("*.microsoftonline.cn");
    $trustedDomains.Add("*.microsoftonline-p.cn");
    $trustedDomains.Add("*.azure.cn");
    $trustedDomains.Add("*.microsoftonline.de");
    $trustedDomains.Add("*.microsoftonline-p.de");
    $trustedDomains.Add("*.azure.de");
    $trustedDomains.Add("*.microsoftazure.de");
    $trustedDomains.Add("*.microsoftonline.us");
    $trustedDomains.Add("*.microsoftonline-p.us");
    $trustedDomains.Add("*.azure.us");
    
    # Create trusted domain registry keys.
    foreach ($domain in $trustedDomains)
    {
        $regKeyEscDomain = $TrustedSitesEscDomainsRegistryHive + "\" + $domain
        $regKeyDomain = $TrustedSitesDomainsRegistryHive + "\" + $domain
        
        foreach ($regKey in $regKeyEscDomain,$regKeyDomain)
        {
            if ( -not (Test-Path $regKey))
            {
                Log-Info "Creating $regKey"
                New-Item -Path $regKey -Force
            }
            
            # Add https key and setting its value to 2.
            New-ItemProperty -Path $regKey -Name "https" -Value 2 -Force
        }	
    }
}

<#
.SYNOPSIS
    Create blank registry keys.
#>
function AddBlankRegistryKeys
{
    foreach ($regKey in $regKeyEscBlankDomain,$regKeyBlankDomain)
    {
        if ( -not (Test-Path $regKey))
        {
            Log-Info "Creating $regKey"
            New-Item -Path $regKey -Force
        }
        
        # Add about registry key and setting its value to 2.
        New-ItemProperty -Path $regKey -Name "about" -Value 2 -Force
    }
}

###############
## Main flow ##
###############

try
{
    # List of registry hives.
    $registryHives = New-Object System.Collections.Generic.List[string]
    $registryHives.Add($InternetSettingsRegistryHive);
    $registryHives.Add($TrustedSitesEscDomainsRegistryHive);
    $registryHives.Add($TrustedSitesDomainsRegistryHive);
    $registryHives.Add($InternetExplorerRegistryHive);
    $registryHives.Add($regKeyIEAllow);

    # Create registry hives.
    foreach ($regHive in $registryHives)
    {
        if ( -not (Test-Path $regHive))
        {
            Log-Info "Creating $regHive"
            New-Item -Path $regHive -Force
        }
    }
     
    New-ItemProperty -Path $InternetExplorerRegistryHive -Name "PopupMgr" -Value 0 -Force
    New-ItemProperty -Path $InternetSettingsRegistryHive -Name "WarnonZoneCrossing" -Value 0 -Force

    AddTrustedLocalDomains
    AddTrustedDomains
    AddBlankRegistryKeys

    if ($LaunchApplication)
        {
        # Launch url.
        Log-Info "Launching url - $DefaultURL"
        Start $DefaultURL
    }

    #Create a shortcut for launching appliance portal
    $Shell = New-Object -ComObject ("WScript.Shell")
    $ShortCut = $Shell.CreateShortcut($env:PUBLIC + "\Desktop\Azure Migrate Appliance Configuration Manager.lnk")
    $ShortCut.TargetPath = $DefaultURL
    $ShortCut.IconLocation =  $env:ProgramFiles + "\Microsoft Azure Appliance Configuration Manager\favicon.ico"   
    $ShortCut.Save()
}
catch
{
    Log-Error "Script execution failed with error: $_.Exception.Message"
    Log-Error "Error Record: $_.Exception.ErrorRecord"
    Log-Error "Exception caught:  $_.Exception"
    exit 1
}
# SIG # Begin signature block
# MIIjewYJKoZIhvcNAQcCoIIjbDCCI2gCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAOKwdD98N3Gh35
# Y9Eo83rI2MZSWPTOD4quUiP/8dx8faCCDXYwggX0MIID3KADAgECAhMzAAABhk0h
# daDZB74sAAAAAAGGMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMjAwMzA0MTgzOTQ2WhcNMjEwMzAzMTgzOTQ2WjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQC49eyyaaieg3Xb7ew+/hA34gqzRuReb9svBF6N3+iLD5A0iMddtunnmbFVQ+lN
# Wphf/xOGef5vXMMMk744txo/kT6CKq0GzV+IhAqDytjH3UgGhLBNZ/UWuQPgrnhw
# afQ3ZclsXo1lto4pyps4+X3RyQfnxCwqtjRxjCQ+AwIzk0vSVFnId6AwbB73w2lJ
# +MC+E6nVmyvikp7DT2swTF05JkfMUtzDosktz/pvvMWY1IUOZ71XqWUXcwfzWDJ+
# 96WxBH6LpDQ1fCQ3POA3jCBu3mMiB1kSsMihH+eq1EzD0Es7iIT1MlKERPQmC+xl
# K+9pPAw6j+rP2guYfKrMFr39AgMBAAGjggFzMIIBbzAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQUhTFTFHuCaUCdTgZXja/OAQ9xOm4w
# RQYDVR0RBD4wPKQ6MDgxHjAcBgNVBAsTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEW
# MBQGA1UEBRMNMjMwMDEyKzQ1ODM4NDAfBgNVHSMEGDAWgBRIbmTlUAXTgqoXNzci
# tW2oynUClTBUBgNVHR8ETTBLMEmgR6BFhkNodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpb3BzL2NybC9NaWNDb2RTaWdQQ0EyMDExXzIwMTEtMDctMDguY3JsMGEG
# CCsGAQUFBwEBBFUwUzBRBggrBgEFBQcwAoZFaHR0cDovL3d3dy5taWNyb3NvZnQu
# Y29tL3BraW9wcy9jZXJ0cy9NaWNDb2RTaWdQQ0EyMDExXzIwMTEtMDctMDguY3J0
# MAwGA1UdEwEB/wQCMAAwDQYJKoZIhvcNAQELBQADggIBAEDkLXWKDtJ8rLh3d7XP
# 1xU1s6Gt0jDqeHoIpTvnsREt9MsKriVGKdVVGSJow1Lz9+9bINmPZo7ZdMhNhWGQ
# QnEF7z/3czh0MLO0z48cxCrjLch0P2sxvtcaT57LBmEy+tbhlUB6iz72KWavxuhP
# 5zxKEChtLp8gHkp5/1YTPlvRYFrZr/iup2jzc/Oo5N4/q+yhOsRT3KJu62ekQUUP
# sPU2bWsaF/hUPW/L2O1Fecf+6OOJLT2bHaAzr+EBAn0KAUiwdM+AUvasG9kHLX+I
# XXlEZvfsXGzzxFlWzNbpM99umWWMQPTGZPpSCTDDs/1Ci0Br2/oXcgayYLaZCWsj
# 1m/a0V8OHZGbppP1RrBeLQKfATjtAl0xrhMr4kgfvJ6ntChg9dxy4DiGWnsj//Qy
# wUs1UxVchRR7eFaP3M8/BV0eeMotXwTNIwzSd3uAzAI+NSrN5pVlQeC0XXTueeDu
# xDch3S5UUdDOvdlOdlRAa+85Si6HmEUgx3j0YYSC1RWBdEhwsAdH6nXtXEshAAxf
# 8PWh2wCsczMe/F4vTg4cmDsBTZwwrHqL5krX++s61sLWA67Yn4Db6rXV9Imcf5UM
# Cq09wJj5H93KH9qc1yCiJzDCtbtgyHYXAkSHQNpoj7tDX6ko9gE8vXqZIGj82mwD
# TAY9ofRH0RSMLJqpgLrBPCKNMIIHejCCBWKgAwIBAgIKYQ6Q0gAAAAAAAzANBgkq
# hkiG9w0BAQsFADCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24x
# EDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlv
# bjEyMDAGA1UEAxMpTWljcm9zb2Z0IFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9yaXR5
# IDIwMTEwHhcNMTEwNzA4MjA1OTA5WhcNMjYwNzA4MjEwOTA5WjB+MQswCQYDVQQG
# EwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSgwJgYDVQQDEx9NaWNyb3NvZnQg
# Q29kZSBTaWduaW5nIFBDQSAyMDExMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIIC
# CgKCAgEAq/D6chAcLq3YbqqCEE00uvK2WCGfQhsqa+laUKq4BjgaBEm6f8MMHt03
# a8YS2AvwOMKZBrDIOdUBFDFC04kNeWSHfpRgJGyvnkmc6Whe0t+bU7IKLMOv2akr
# rnoJr9eWWcpgGgXpZnboMlImEi/nqwhQz7NEt13YxC4Ddato88tt8zpcoRb0Rrrg
# OGSsbmQ1eKagYw8t00CT+OPeBw3VXHmlSSnnDb6gE3e+lD3v++MrWhAfTVYoonpy
# 4BI6t0le2O3tQ5GD2Xuye4Yb2T6xjF3oiU+EGvKhL1nkkDstrjNYxbc+/jLTswM9
# sbKvkjh+0p2ALPVOVpEhNSXDOW5kf1O6nA+tGSOEy/S6A4aN91/w0FK/jJSHvMAh
# dCVfGCi2zCcoOCWYOUo2z3yxkq4cI6epZuxhH2rhKEmdX4jiJV3TIUs+UsS1Vz8k
# A/DRelsv1SPjcF0PUUZ3s/gA4bysAoJf28AVs70b1FVL5zmhD+kjSbwYuER8ReTB
# w3J64HLnJN+/RpnF78IcV9uDjexNSTCnq47f7Fufr/zdsGbiwZeBe+3W7UvnSSmn
# Eyimp31ngOaKYnhfsi+E11ecXL93KCjx7W3DKI8sj0A3T8HhhUSJxAlMxdSlQy90
# lfdu+HggWCwTXWCVmj5PM4TasIgX3p5O9JawvEagbJjS4NaIjAsCAwEAAaOCAe0w
# ggHpMBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBRIbmTlUAXTgqoXNzcitW2o
# ynUClTAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTALBgNVHQ8EBAMCAYYwDwYD
# VR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBRyLToCMZBDuRQFTuHqp8cx0SOJNDBa
# BgNVHR8EUzBRME+gTaBLhklodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpL2Ny
# bC9wcm9kdWN0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFfMDNfMjIuY3JsMF4GCCsG
# AQUFBwEBBFIwUDBOBggrBgEFBQcwAoZCaHR0cDovL3d3dy5taWNyb3NvZnQuY29t
# L3BraS9jZXJ0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFfMDNfMjIuY3J0MIGfBgNV
# HSAEgZcwgZQwgZEGCSsGAQQBgjcuAzCBgzA/BggrBgEFBQcCARYzaHR0cDovL3d3
# dy5taWNyb3NvZnQuY29tL3BraW9wcy9kb2NzL3ByaW1hcnljcHMuaHRtMEAGCCsG
# AQUFBwICMDQeMiAdAEwAZQBnAGEAbABfAHAAbwBsAGkAYwB5AF8AcwB0AGEAdABl
# AG0AZQBuAHQALiAdMA0GCSqGSIb3DQEBCwUAA4ICAQBn8oalmOBUeRou09h0ZyKb
# C5YR4WOSmUKWfdJ5DJDBZV8uLD74w3LRbYP+vj/oCso7v0epo/Np22O/IjWll11l
# hJB9i0ZQVdgMknzSGksc8zxCi1LQsP1r4z4HLimb5j0bpdS1HXeUOeLpZMlEPXh6
# I/MTfaaQdION9MsmAkYqwooQu6SpBQyb7Wj6aC6VoCo/KmtYSWMfCWluWpiW5IP0
# wI/zRive/DvQvTXvbiWu5a8n7dDd8w6vmSiXmE0OPQvyCInWH8MyGOLwxS3OW560
# STkKxgrCxq2u5bLZ2xWIUUVYODJxJxp/sfQn+N4sOiBpmLJZiWhub6e3dMNABQam
# ASooPoI/E01mC8CzTfXhj38cbxV9Rad25UAqZaPDXVJihsMdYzaXht/a8/jyFqGa
# J+HNpZfQ7l1jQeNbB5yHPgZ3BtEGsXUfFL5hYbXw3MYbBL7fQccOKO7eZS/sl/ah
# XJbYANahRr1Z85elCUtIEJmAH9AAKcWxm6U/RXceNcbSoqKfenoi+kiVH6v7RyOA
# 9Z74v2u3S5fi63V4GuzqN5l5GEv/1rMjaHXmr/r8i+sLgOppO6/8MO0ETI7f33Vt
# Y5E90Z1WTk+/gFcioXgRMiF670EKsT/7qMykXcGhiJtXcVZOSEXAQsmbdlsKgEhr
# /Xmfwb1tbWrJUnMTDXpQzTGCFVswghVXAgEBMIGVMH4xCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNp
# Z25pbmcgUENBIDIwMTECEzMAAAGGTSF1oNkHviwAAAAAAYYwDQYJYIZIAWUDBAIB
# BQCgga4wGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEO
# MAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIOg9/qFj/ji3X/YEfQ/kxBdK
# rzLzRcB9GtX8BKlDdd+lMEIGCisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8A
# cwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEB
# BQAEggEAfKGMKcOFr5zHoLrWxulJ7J15yEoupPVquPZQigS2HS/GCiZJYvnLQICV
# epq/sBCBXpy3yWZRSxlE6aFppDyn4KcCgs2d+qIjFuOjq2fOvt1Clurd5pPbEbG0
# iTv+EnwIjopXrHRkNdc6H+g89SgNpyLoqxtsX2fOBqEkMHJdGrNkHylA2AkLg+Ib
# eX6eWF3xAzrsl06Ac8LiFVsQSt/9YDEfMO2239sJB8BwO1O2MBE5BVGlvKCzh6Cm
# aeHJtPDKbXJ+hz8Aj/cekBmMOSkp2IT0qk7kCWgbf3p/3bkKjAye0jQ4YgmirZ3L
# VGPlQJkLRQeCZYbIic5EQEJ9u+6Uh6GCEuUwghLhBgorBgEEAYI3AwMBMYIS0TCC
# Es0GCSqGSIb3DQEHAqCCEr4wghK6AgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFRBgsq
# hkiG9w0BCRABBKCCAUAEggE8MIIBOAIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFl
# AwQCAQUABCAhlW3zEZM/5hSzrQYYqReN5R6ZFbgyE0viMN3JGyicGgIGX1/+OeB7
# GBMyMDIwMDkyNDE5NDgwMC4yMzZaMASAAgH0oIHQpIHNMIHKMQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1l
# cmljYSBPcGVyYXRpb25zMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjpBRTJDLUUz
# MkItMUFGQzElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZaCC
# DjwwggTxMIID2aADAgECAhMzAAABFpMi6r+7LU3mAAAAAAEWMA0GCSqGSIb3DQEB
# CwUAMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQH
# EwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNV
# BAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMB4XDTE5MTExMzIxNDAz
# NFoXDTIxMDIxMTIxNDAzNFowgcoxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNo
# aW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29y
# cG9yYXRpb24xJTAjBgNVBAsTHE1pY3Jvc29mdCBBbWVyaWNhIE9wZXJhdGlvbnMx
# JjAkBgNVBAsTHVRoYWxlcyBUU1MgRVNOOkFFMkMtRTMyQi0xQUZDMSUwIwYDVQQD
# ExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNlMIIBIjANBgkqhkiG9w0BAQEF
# AAOCAQ8AMIIBCgKCAQEA0Pgb8/296ie/Lj2rWq+MIlMZwkSUwZsIKd472tyeVOyN
# cKgqSCT4zQvz2kd+VD7lYWN3V0USL5oipdp+xp7wH7CAHC7zNU21PjdHWPOi2okI
# lPyTikrQBowo+MOV9Xgd3WqMnJSKEank7QmSHgJimJ2q/ZRR5+0Z5uZRejJHkQcJ
# mTB8Gq/wg2E/gjuRl/iGa4fGJu0cHSUiX78m5FEyaac1XnkqafSqYR8qb7sn3ZVt
# /ltbiGUJr874oi2bZduUtCMR0QiWWfBMExcLV4A6ermC98cbbvi/pQb1p1l7vXT2
# NReD+xkFqzKn0cA3Vi9cc5LjDhY91L18RuHIgU3qHQIDAQABo4IBGzCCARcwHQYD
# VR0OBBYEFOW/Xiu4F+gXzUflH3k0/lfIIVULMB8GA1UdIwQYMBaAFNVjOlyKMZDz
# Q3t8RhvFM2hahW1VMFYGA1UdHwRPME0wS6BJoEeGRWh0dHA6Ly9jcmwubWljcm9z
# b2Z0LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL01pY1RpbVN0YVBDQV8yMDEwLTA3LTAx
# LmNybDBaBggrBgEFBQcBAQROMEwwSgYIKwYBBQUHMAKGPmh0dHA6Ly93d3cubWlj
# cm9zb2Z0LmNvbS9wa2kvY2VydHMvTWljVGltU3RhUENBXzIwMTAtMDctMDEuY3J0
# MAwGA1UdEwEB/wQCMAAwEwYDVR0lBAwwCgYIKwYBBQUHAwgwDQYJKoZIhvcNAQEL
# BQADggEBADaDatfaqaPbAy/pSdK8e8XdzN6v9979NSWLUsNHoNBFpyr1FTGcvwf0
# SKIfe0ygt8s8plkAYxMUftUmOnO+OnGXUgTOreXIw4ztsepotreHcL094+bn7OUG
# LPMa56GQii3WUgiGPP0gfNXhXcqSdd9HmXjMhKfRn0jOKREJTPqPHLXSxcA1SVTr
# g8JDtkD+yWVzuuAkSopTGxtJp5PcrYUrMb7nW1coIe7tsQiSPp6xFVzKfXFUJ9Vz
# AChucE+8pqXLpV/xU3p/1vf0DgLZMpI22mwAgbe/E6wgyDSKyHXI4UsiIlSYASv+
# IlKOtcXzrXV0IRQUdRyIC1ZiWWL/YggwggZxMIIEWaADAgECAgphCYEqAAAAAAAC
# MA0GCSqGSIb3DQEBCwUAMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGlu
# Z3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBv
# cmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQgUm9vdCBDZXJ0aWZpY2F0ZSBBdXRo
# b3JpdHkgMjAxMDAeFw0xMDA3MDEyMTM2NTVaFw0yNTA3MDEyMTQ2NTVaMHwxCzAJ
# BgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25k
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jv
# c29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8A
# MIIBCgKCAQEAqR0NvHcRijog7PwTl/X6f2mUa3RUENWlCgCChfvtfGhLLF/Fw+Vh
# wna3PmYrW/AVUycEMR9BGxqVHc4JE458YTBZsTBED/FgiIRUQwzXTbg4CLNC3ZOs
# 1nMwVyaCo0UN0Or1R4HNvyRgMlhgRvJYR4YyhB50YWeRX4FUsc+TTJLBxKZd0WET
# bijGGvmGgLvfYfxGwScdJGcSchohiq9LZIlQYrFd/XcfPfBXday9ikJNQFHRD5wG
# Pmd/9WbAA5ZEfu/QS/1u5ZrKsajyeioKMfDaTgaRtogINeh4HLDpmc085y9Euqf0
# 3GS9pAHBIAmTeM38vMDJRF1eFpwBBU8iTQIDAQABo4IB5jCCAeIwEAYJKwYBBAGC
# NxUBBAMCAQAwHQYDVR0OBBYEFNVjOlyKMZDzQ3t8RhvFM2hahW1VMBkGCSsGAQQB
# gjcUAgQMHgoAUwB1AGIAQwBBMAsGA1UdDwQEAwIBhjAPBgNVHRMBAf8EBTADAQH/
# MB8GA1UdIwQYMBaAFNX2VsuP6KJcYmjRPZSQW9fOmhjEMFYGA1UdHwRPME0wS6BJ
# oEeGRWh0dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL01p
# Y1Jvb0NlckF1dF8yMDEwLTA2LTIzLmNybDBaBggrBgEFBQcBAQROMEwwSgYIKwYB
# BQUHMAKGPmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2kvY2VydHMvTWljUm9v
# Q2VyQXV0XzIwMTAtMDYtMjMuY3J0MIGgBgNVHSABAf8EgZUwgZIwgY8GCSsGAQQB
# gjcuAzCBgTA9BggrBgEFBQcCARYxaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL1BL
# SS9kb2NzL0NQUy9kZWZhdWx0Lmh0bTBABggrBgEFBQcCAjA0HjIgHQBMAGUAZwBh
# AGwAXwBQAG8AbABpAGMAeQBfAFMAdABhAHQAZQBtAGUAbgB0AC4gHTANBgkqhkiG
# 9w0BAQsFAAOCAgEAB+aIUQ3ixuCYP4FxAz2do6Ehb7Prpsz1Mb7PBeKp/vpXbRkw
# s8LFZslq3/Xn8Hi9x6ieJeP5vO1rVFcIK1GCRBL7uVOMzPRgEop2zEBAQZvcXBf/
# XPleFzWYJFZLdO9CEMivv3/Gf/I3fVo/HPKZeUqRUgCvOA8X9S95gWXZqbVr5MfO
# 9sp6AG9LMEQkIjzP7QOllo9ZKby2/QThcJ8ySif9Va8v/rbljjO7Yl+a21dA6fHO
# mWaQjP9qYn/dxUoLkSbiOewZSnFjnXshbcOco6I8+n99lmqQeKZt0uGc+R38ONiU
# 9MalCpaGpL2eGq4EQoO4tYCbIjggtSXlZOz39L9+Y1klD3ouOVd2onGqBooPiRa6
# YacRy5rYDkeagMXQzafQ732D8OE7cQnfXXSYIghh2rBQHm+98eEA3+cxB6STOvdl
# R3jo+KhIq/fecn5ha293qYHLpwmsObvsxsvYgrRyzR30uIUBHoD7G4kqVDmyW9rI
# DVWZeodzOwjmmC3qjeAzLhIp9cAvVCch98isTtoouLGp25ayp0Kiyc8ZQU3ghvkq
# mqMRZjDTu3QyS99je/WZii8bxyGvWbWu3EQ8l1Bx16HSxVXjad5XwdHeMMD9zOZN
# +w2/XU/pnR4ZOC+8z1gFLu8NoFA12u8JJxzVs341Hgi62jbb01+P3nSISRKhggLO
# MIICNwIBATCB+KGB0KSBzTCByjELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hp
# bmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jw
# b3JhdGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEm
# MCQGA1UECxMdVGhhbGVzIFRTUyBFU046QUUyQy1FMzJCLTFBRkMxJTAjBgNVBAMT
# HE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2WiIwoBATAHBgUrDgMCGgMVAIdN
# W9zyT6CLG1qCDNc++szs3ZZDoIGDMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNV
# BAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jv
# c29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAg
# UENBIDIwMTAwDQYJKoZIhvcNAQEFBQACBQDjFwKfMCIYDzIwMjAwOTI0MTkzMzUx
# WhgPMjAyMDA5MjUxOTMzNTFaMHcwPQYKKwYBBAGEWQoEATEvMC0wCgIFAOMXAp8C
# AQAwCgIBAAICGHUCAf8wBwIBAAICEbIwCgIFAOMYVB8CAQAwNgYKKwYBBAGEWQoE
# AjEoMCYwDAYKKwYBBAGEWQoDAqAKMAgCAQACAwehIKEKMAgCAQACAwGGoDANBgkq
# hkiG9w0BAQUFAAOBgQAbv3RrLBTuW6vcM0MdWIF7KMq6RCeFWXtJ2ayC0Z95GHyx
# VYfrfqIhUuMtKhMN5S5ZffDdmCgr6e6mAObec94fQyVdAAjmF9Xa3d+aDGJcjElc
# Nul7O6JFhcpRzqi5SPEoIz7omOEQJyHOoTNaJsBWc4f+qZDhn6Dk3RraPMFdTTGC
# Aw0wggMJAgEBMIGTMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9u
# MRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRp
# b24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAAB
# FpMi6r+7LU3mAAAAAAEWMA0GCWCGSAFlAwQCAQUAoIIBSjAaBgkqhkiG9w0BCQMx
# DQYLKoZIhvcNAQkQAQQwLwYJKoZIhvcNAQkEMSIEIK0aTTfDfXrRqt4SNfC0t/B4
# 87uII0tpsJs4hOgevyh9MIH6BgsqhkiG9w0BCRACLzGB6jCB5zCB5DCBvQQggyKU
# 9qRgKQiXXCmbITbdtLENhYxqIMhBaM+iXtLBkMowgZgwgYCkfjB8MQswCQYDVQQG
# EwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQg
# VGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAARaTIuq/uy1N5gAAAAABFjAiBCA4KRVY
# rD7T0mPoaz2gDIUDxNAePUiBjrlP3CVQArVeoTANBgkqhkiG9w0BAQsFAASCAQCq
# PbnH8tsxKOQHP4IZ/Wwft3fwo3pQWcFZIy0nDk3c/+k3cT1REAjhF7byCyrb8gPx
# IAFFcb7bb7nM6rZ1tPE/ImL2TmNP8Q3Bl3EfIU7DdzzkqyORUuqp0av88We/uNH0
# 3hzPVqRWdGOHw3aG5IplC61NRvoaS3lqtzmYeLWGFEF1ZJ5gjyYMqwWosAfN5imo
# b7QXycfhKQQ06UirIe8Cm7ssTasvZy38t61mBbe0exy8IQgSbNWW/+Uq7PLcu9EU
# 2iegsYhbbF9uUq+Sv4INleObeXCNHAkfwF4n1fJCsPvi7nGQJDofmJedkXUritQc
# +RTqHNM8+BHwfigqWOBE
# SIG # End signature block
