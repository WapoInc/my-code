# -------------------------------------------------------------------------------------------------
#  <copyright file="AzureMigrateInstaller.ps1" company="Microsoft">
#      Copyright (c) Microsoft Corporation. All rights reserved.
#  </copyright>
#
#  Description: This script prepares the host machine for various Azure Migrate Scenarios.

#  Version: 6.0.2.0

#  Requirements: 
#       Refer Readme.html for machine requirements 
#       Following files should be placed in the same folder as this script before execution:
#            Scripts : WebBinding.ps1 and SetRegistryForTrustedSites.ps1
#            MSIs    : Microsoft Azure Hyper-V\Server\VMware Assessment Service.msi
#                      Microsoft Azure Hyper-V\Server\VMware Discovery Service.msi
#                      MicrosoftAzureApplianceConfigurationManager.msi
#                      MicrosoftAzureAutoUpdate.msi
#                      MicrosoftAzureDraService.msi     (VMware Migration only)
#                      MicrosoftAzureGatewayService.exe (VMware Migration only)
#            Config  : Scenario.json 
#                      {
#                           "FabricType" : "HyperV|Physical|VMware"
#                           "Cloud"      : "Public|USGov|USNat"
#                      }
# -------------------------------------------------------------------------------------------------

#Requires -RunAsAdministrator

[CmdletBinding(DefaultParameterSetName="None")]
param(
    [Parameter(Mandatory = $false, ParameterSetName = "NewInstall")] 
    [ValidateNotNullOrEmpty()] 
    [ValidateSet('HyperV','Physical','VMware')]
    [string]
    $Scenario,

    [Parameter(Mandatory = $false, ParameterSetName = "NewInstall")] 
    [ValidateNotNullOrEmpty()] 
    [ValidateSet('Public','USGov','USNat')]
    [string]
    $Cloud,

    [Parameter(Mandatory = $false, ParameterSetName = "NewInstall")]
    [Parameter(Mandatory = $false, ParameterSetName = "Upgrade")]
    [Parameter(Mandatory = $false, ParameterSetName = "None")]
    [switch]
    $SkipSettingTrustedHost,

    [Parameter(Mandatory = $false, ParameterSetName = "Upgrade")]
    [switch]
    $UpgradeAgents
)

## This routine writes the output string to the console and also to a log file.
function Log-Info([string] $OutputText)
{
    Write-Host $OutputText -ForegroundColor White
    $OutputText = [string][DateTime]::Now + " " + $OutputText
    $OutputText | %{ Out-File -filepath $InstallerLog -inputobject $_ -append -encoding "ASCII" }
}

function Log-Success([string] $OutputText)
{
    Write-Host $OutputText -ForegroundColor Green
    $OutputText = [string][DateTime]::Now + " " + $OutputText
    $OutputText | %{ Out-File -filepath $InstallerLog -inputobject $_ -append -encoding "ASCII" }
}

## This routine writes the output string to the console and also to a log file.
function Log-Warning([string] $OutputText)
{
    Write-Host $OutputText -ForegroundColor Yellow
    $OutputText = [string][DateTime]::Now + " " + $OutputText
    $OutputText | %{ Out-File -filepath $InstallerLog -inputobject $_ -append -encoding "ASCII"  }
}

## This routine writes the output string to the console and also to a log file.
function Log-Error([string] $OutputText)
{
    Write-Host $OutputText -ForegroundColor Red
    $OutputText = [string][DateTime]::Now + " " + $OutputText
    $OutputText | %{ Out-File -filepath $InstallerLog -inputobject $_ -append -encoding "ASCII" }
}

## Global Initialization
$global:DefaultStringVal  = "Unknown"
$global:WarningCount      = 0
$global:ReuseScenario     = 0
$global:SelectedFabricType= $global:DefaultStringVal 
$global:SelectedCloud     = $global:DefaultStringVal 
$global:SelectedScaleOut  = "None" 

$machineHostName          = (Get-WmiObject win32_computersystem).DNSHostName
$DefaultURL               = "https://" + $machineHostName + ":44368"
$TimeStamp                = [DateTime]::Now.ToString("yyyy-MM-dd-HH-mm-ss")
$BackupDir                = "$env:ProgramData`\Microsoft Azure"
$BackupDestination        = "$env:windir`\Temp\MicrosoftAzure"
$LogFileDir               = "$env:ProgramData`\Microsoft Azure\Logs"
$ConfigFileDir            = "$env:ProgramData`\Microsoft Azure\Config"
# TODO: Move reading this path from registry if it exists
$CredFileDir              = "$env:ProgramData`\Microsoft Azure\CredStore"
$ApplianceVersionFilePath = "$Env:SystemDrive`\Users\Public\Desktop\ApplianceVersion.txt"

$HyperVAssessmentServiceMSI    = "Microsoft Azure Hyper-V Assessment Service.msi"
$HyperVDiscoveryServiceMSI     = "Microsoft Azure Hyper-V Discovery Service.msi"
$ServerAssessmentServiceMSI    = "Microsoft Azure Server Assessment Service.msi"
$ServerDiscoveryServiceMSI     = "Microsoft Azure Server Discovery Service.msi"
$VMWareAssessmentServiceMSI    = "Microsoft Azure VMware Assessment Service.msi"
$VMWareDiscoveryServiceMSI     = "Microsoft Azure VMware Discovery Service.msi"

$AssessmentServiceMSILog = "$LogFileDir\AssessmentInstaller_$TimeStamp.log"
$DiscoveryServiceMSILog  = "$LogFileDir\DiscoveryInstaller_$TimeStamp.log"

$GatewayExeName          = "MicrosoftAzureGatewayService.exe"
$DraMsiName              = "MicrosoftAzureDRAService.msi"
$DraMsiLog               = "$LogFileDir\DRAInstaller_$TimeStamp.log"

$WebAppMSI               = "MicrosoftAzureApplianceConfigurationManager.msi"
$WebAppMSILog            = "$LogFileDir\ConfigurationManagerInstaller_$TimeStamp.log"
$ApplianceJsonFilePath   = "$ConfigFileDir\appliance.json"
$ApplianceJsonFileData   = @{
    "Cloud"="$global:SelectedCloud";
    "ComponentVersion"="2.0.0.0";
    "FabricType"="$global:SelectedFabricType";
    "VddkInstallerFolder"="";
    "IsApplianceRegistered"="false";
    "EnableProxyBypassList"="false";
    "ProviderId"="8416fccd-8af8-466e-8021-79db15038c87";
}

$AutoUpdaterMSI          = "MicrosoftAzureAutoUpdate.msi"
$AutoUpdaterMSILog       = "$LogFileDir\AutoUpdateInstaller_$TimeStamp.log"
$AutoUpdaterJsonFilePath = "$ConfigFileDir\AutoUpdater.json"
$AutoUpdaterJsonFileData = @{
    "Cloud"="$global:SelectedCloud";
    "ComponentVersion"="2.0.0.0";
    "AutoUpdateEnabled"="True";
    "ProviderId"="8416fccd-8af8-466e-8021-79db15038c87";
    "AutoUpdaterDownloadLink"="https://aka.ms/latestapplianceservices"
}

$RegAzureAppliancePath = "HKLM:\SOFTWARE\Microsoft\Azure Appliance"
$RegAzureCredStorePath = "HKLM:\Software\Microsoft\AzureAppliance"

## Creating the logfile
New-Item -ItemType Directory -Force -Path $LogFileDir | Out-Null
$InstallerLog = "$LogFileDir\AzureMigrateScenarioInstaller_$TimeStamp.log"
Log-Success "Log file created `"$InstallerLog`" for troubleshooting purpose.`n"

<#
.SYNOPSIS
Create JsonFile
Usage:
    DetectAndCleanupPreviousInstallation
#>
function DetectAndCleanupPreviousInstallation
{ 
    [string] $userChoice = "y"
    
    if([System.IO.File]::Exists($ApplianceJsonFilePath))
    {
        if ($UpgradeAgents -eq $false)
        {
            $jsonContent = Get-Content $ApplianceJsonFilePath | Out-String | ConvertFrom-Json

            if ($jsonContent.IsApplianceRegistered.ToLower() -eq "true")
            {
                do
                {
                    Log-Error "This host has already been registered as an Azure Migrate Appliance. If you choose to proceed with this fresh installation, configuration files from the previous installation will be lost. `nDo you still want to continue, [Y/N]"
                    $userChoice = Read-Host
                }while ("y", "n" -NotContains $userChoice.ToLower()) 

                $global:ReuseScenario = 1
            }
        }

        if ($userChoice.ToLower() -eq "n")
        {
            Log-Warning "Aborting installation..."
            exit 0
        }
        else
        {
            if ($global:ReuseScenario -eq 1)
            {
                $ZipFilePath = "$BackupDestination`\Backup_$TimeStamp.zip"
                Log-Info "Zip and backup the configuration to the path: $ZipFilePath"
                New-Item -ItemType "Directory" -Path BackupDestination -Force            

                ## Compress file.
                [Reflection.Assembly]::LoadWithPartialName( "System.IO.Compression.FileSystem" )
                [System.IO.Compression.ZipFile]::CreateFromDirectory($BackupDir, $ZipFilePath) | Out-Null
            }

            Log-Info "Removing previously installed agents (if found installed) in 10 seconds..."
            Start-Sleep -Seconds 10

            UnInstallProgram("Microsoft Azure Server Assessment Service")
            UnInstallProgram("Microsoft Azure Server Discovery Service")
            UnInstallProgram("Microsoft Azure Hyper-V Assessment Service")
            UnInstallProgram("Microsoft Azure Hyper-V Discovery Service")
            UnInstallProgram("Microsoft Azure VMware Assessment Service")
            UnInstallProgram("Microsoft Azure VMware Discovery Service")
            UnInstallProgram("Microsoft Azure Appliance Auto Update")
            UnInstallProgram("Microsoft Azure Appliance Configuration Manager")
            UnInstallProgram("Microsoft Azure Dra Service")
            UnInstallProgram("Microsoft Azure Gateway Service")

            #Restart IIS
            iisreset.exe /restart | Out-Null

            if ($UpgradeAgents -eq $false)
            {
                Log-info "Cleaning up previous configuration files and settings..."

                if([System.IO.File]::Exists($ApplianceVersionFilePath))
                {
                    Remove-Item -path $ApplianceVersionFilePath -Force
                }

                if([System.IO.File]::Exists($AutoUpdaterJsonFilePath))
                {
                    Remove-Item –path $AutoUpdaterJsonFilePath -Force
                }

                if (Test-Path $RegAzureCredStorePath)
                {
                    Remove-Item -Path $RegAzureCredStorePath -Force
                }

                if (Test-Path $ConfigFileDir -PathType Any)
                {
                    Remove-Item –path $ApplianceJsonFilePath
                    Remove-Item -Recurse -Force $ConfigFileDir
                }

                if (Test-Path $CredFileDir -PathType Container)
                {
                    Remove-Item -Recurse -Force $CredFileDir
                }

                if (Test-Path $LogFileDir -PathType Container)
                {
                    # Remove all folders under Log folder.
                    Get-ChildItem -Recurse $LogFileDir | Where { $_.PSIsContainer } | Remove-Item -Recurse -Force
                }
                
                if(Test-Path $RegAzureAppliancePath)
                {
                    Remove-Item $RegAzureAppliancePath -Force
                }
            }

            if ($Error.Count -eq 0)
            {
                Log-Success "[OK]`n"
            }
            else
            {
                Log-Error "Failure in cleanup. Aborting..."
                Log-Warning "Please take remedial action on the below error or contact Microsoft Support for help."
                Log-Error $Error
                exit -2
            }
        }
    }
}

<#
.SYNOPSIS
Install MSI
Usage:
    UnInstallProgram -ProgramCaption $ProgramCaption
#>

function UnInstallProgram
{
    param(
        [string] $ProgramCaption
        )

    $app = Get-WmiObject -Class Win32_Product -Filter "Caption = '$ProgramCaption' "

    if ($app)
    {
        Log-Warning "$ProgramCaption found installed. Proceeding with uninstallation."
        $app.Uninstall()   
        
        if ($?)
        {
            Log-Success "[Uninstall Successful]`n"
        }
        else
        {
            $global:WarningCount++
            Log-Warning "Warning #$global:WarningCount : Unable to uninstall successfully. Please manually uninstall $ProgramCaption from Control Panel. Continuing..."
        } 
    }

    $Error.Clear()
}

<#
.SYNOPSIS
Install MSI
Usage:
    InstallMSI -MSIFilePath $MSIFilePath -MSIInstallLogName $MSIInstallLogName
#>

function InstallMSI
{ 
    param(
        [string] $MSIFilePath,
        [string] $MSIInstallLogName
        )

    Log-Info "Installing $MSIFilePath..."

    if (-Not (Test-Path -Path $MSIFilePath -PathType Any))
    {
        Log-Error "MSI not found: $MSIFilePath. Aborting..."
        Log-Warning "Please ensure all MSIs are copied to the same folder as the current script."
        exit -3
    }

    $process = (Start-Process -Wait -Passthru -FilePath msiexec -ArgumentList `
        "/i `"$MSIFilePath`" /quiet /lv `"$MSIInstallLogName`"")

    $returnCode = $process.ExitCode;
    
    if ($returnCode -eq 0 -or $returnCode -eq 3010) 
    {
        Log-Success "[OK]`n"
    }
    else
    {
        Log-Error "$MSIFilePath installation failed. More logs available at $MSIInstallLogName. Aborting..."
        Log-Warning "Please refer to http://www.msierrors.com/ to get details about the error code: $returnCode. Please share the installation log file $MSIInstallLogName while contacting Microsoft Support."
        exit -3
    }
}

<#
.SYNOPSIS
Create JsonFile
Usage:
    CreateJsonFile -JsonFileData $JsonFileData -JsonFilePath $JsonFilePath
#>
function CreateJsonFile
{ 
    param(
        $JsonFileData,
        [string] $JsonFilePath
        )
    
    if ($UpgradeAgents -and (test-path -path $JsonFilePath))
    {
        Log-Info "Skip creating config file:  $JsonFilePath..."
        return;
    }

    Log-Info "Creating config file: $JsonFilePath..."

    New-Item -Path $ConfigFileDir -type directory -Force | Out-Null
    $JsonFileData | ConvertTo-Json | Add-Content -Path $JsonFilePath -Encoding UTF8

    if ($?)
    {
        Log-Success "[OK]`n"
    }
    else
    {
        Log-Error "Failure in creating $JsonFilePath. Aborting..."
        exit -4
    }
}

<#
.SYNOPSIS
Enables IIS modules.
Usage:
    EnableIIS 
#>

function EnableIIS
{
    Log-Info "Enabling IIS Role and dependent features..."

        Install-WindowsFeature PowerShell-ISE, WAS, WAS-Process-Model, WAS-Config-APIs, Web-Server, `
        Web-WebServer, Web-Mgmt-Service, Web-Request-Monitor, Web-Common-Http, Web-Static-Content, `
        Web-Default-Doc, Web-Dir-Browsing, Web-Http-Errors, Web-App-Dev, Web-CGI, Web-Health, `
        Web-Http-Logging, Web-Log-Libraries, Web-Security, Web-Filtering, Web-Performance, `
        Web-Stat-Compression, Web-Mgmt-Tools, Web-Mgmt-Console, Web-Scripting-Tools, `
        Web-Asp-Net45, Web-Net-Ext45, Web-Http-Redirect, Web-Windows-Auth, Web-Url-Auth

    if ($?)
    {
        Log-Success "[OK]`n"
    }
    else
    {
        Log-Error "Failure to enable the required role(s) with error $Errors. Aborting..."
        Log-Warning "Please ensure the following roles are enabled manually: PowerShell-ISE, `
            WAS (Windows Activation Service), WAS-Process-Model, WAS-Config-APIs, Web-Server (IIS), '
            Web-WebServer, Web-Mgmt-Service, Web-Request-Monitor, Web-Common-Http, Web-Static-Content, '
            Web-Default-Doc, Web-Dir-Browsing, Web-Http-Errors, Web-App-Dev, Web-CGI, Web-Health,'
            Web-Http-Logging, Web-Log-Libraries, Web-Security, Web-Filtering, Web-Performance, '
            Web-Stat-Compression, Web-Mgmt-Tools, Web-Mgmt-Console, Web-Scripting-Tools, '
            Web-Asp-Net45, Web-Net-Ext45, Web-Http-Redirect, Web-Windows-Auth, Web-Url-Auth"
        exit -5
    }
}

<#
.SYNOPSIS
Add AzureCloud registry which used to identify NationalCloud
Usage:
    AddAzureCloudRegistry 
#>

function AddingRegistryKeys
{ 
    Log-Info "Adding\Updating Registry Keys...`n"
    $AzureCloudName = "Public"

    if ( -not (Test-Path $RegAzureAppliancePath))
    {
        Log-Info "`tCreating Registry Node: $RegAzureAppliancePath"
        New-Item -Path $RegAzureAppliancePath -Force | Out-Null
    }
            
    New-ItemProperty -Path $RegAzureAppliancePath -Name AzureCloud -Value $AzureCloudName `
        -Force | Out-Null
    New-ItemProperty -Path $RegAzureAppliancePath -Name Type -Value Physical -Force | Out-Null

    if ( -not (Test-Path $RegAzureCredStorePath))
    {
        Log-Info "`tCreating Registry Node: $RegAzureCredStorePath"
        New-Item -Path $RegAzureCredStorePath -Force | Out-Null
    }

    New-ItemProperty -Path $RegAzureCredStorePath -Name CredStoreDefaultPath `
        -value "%Programdata%\Microsoft Azure\CredStore\Credentials.json" -Force | Out-Null

    if ( $?)
    {
        Log-Success "`n[OK]`n"
    }
    else 
    {
        Log-Error "Failed to add\update registry keys. Aborting..."
        Log-Warning "Please ensure that the current user has access to adding registry keys under the path: $RegAzureAppliancePath or $RegAzureCredStorePath"
        exit -6
    }
}

<#
.SYNOPSIS
Validate OS version
Usage:
    ValidateOSVersion
#>
function ValidateOSVersion
{
    [System.Version]$ver = "0.0"
    [System.Version]$minVer = "10.0"

    Log-Info "Verifying supported Operating System version..."

    $OS = Get-WmiObject Win32_OperatingSystem
    $ver = $OS.Version

    If ($ver -lt $minVer)
    {
        Log-Error "The os version is $ver, minimum supported version is Windows Server 2016 ($minVer). Aborting..."
        log-Warning "Core and Client SKUs are not supported."
        exit -7
    }
    elseif ($OS.Caption.contains("Server") -eq $false)
    {
        Log-Error "OS should be Windows Server 2016. Aborting..."
        log-Warning "Core and Client SKUs are not supported."
        exit -8
    }
    else
    {
        Log-Success "[OK]`n"
    }
}

<#
.SYNOPSIS
custom script run after the Windows Setup process.
Usage:
    CreateApplianceVersionFile
#>

function CreateApplianceVersionFile
{
    Log-Info "Creating Appliance Version File..."
    $ApplianceVersion = "6." + (Get-Date).ToString('yy.MM.dd')
    $fileContent = "$ApplianceVersion"
    
    if([System.IO.File]::Exists($ApplianceVersionFilePath))
    {
        Remove-Item -path $ApplianceVersionFilePath -Force
    }

    # Create Appliance version text file.
    New-Item $ApplianceVersionFilePath -ItemType File -Value $ApplianceVersion -Force | Out-Null
    Set-ItemProperty $ApplianceVersionFilePath -name IsReadOnly -value $true

    if ($?)
    {
        Log-Success "[OK]`n"
    }
    else 
    {
        Log-Warning "Failed to create Appliance Version file with at $ApplianceVersionFilePath. Continuing..."
    }
}

<#
.SYNOPSIS
Download and install IIS rewrite module.
Usage:
    InstallRewriteModule
#>

function InstallRewriteModule
{
    if ((Get-WMIObject -Query "SELECT * FROM Win32_Product Where Name Like 'IIS URL Rewrite Module 2'").Name.Length -gt 0)
    {
        Log-Info "IIS URL Rewrite Module 2.1 is already installed. Skipping download & installation..."
        Log-Success "[OK]`n"
        return
    }

    # Add check to validate if the module is already installed and skip download and install again.
    Log-Info "Installing IIS URL Rewrite Module 2.1"
    $rewriteFile = "$PSScriptRoot\rewrite_amd64_en-US.msi"

    if(![System.IO.File]::Exists($rewriteFile))
    {
        $iisrewriteurl = "https://download.microsoft.com/download/1/2/8/128E2E22-C1B9-44A4-BE2A-5859ED1D4592/rewrite_amd64_en-US.msi"
        Log-Info "Downloading IIS URL Rewrite Module 2.1 from $iisrewriteurl to $rewriteFile"

        Invoke-WebRequest -Uri $iisrewriteurl -OutFile "$rewriteFile"

        if(![System.IO.File]::Exists($rewriteFile))
        {
                Log-Error "Unable to download IIS Rewrite Module 2.1 from the URL:$iisrewriteurl"
                Log-Warning "Manually download IIS Rewrite Module with version 2.1 and place it in the same folder ($PSScriptRoot) as this script"
                exit -10 
        }
    }

    $process = (Start-Process -Wait -Passthru -FilePath "MsiExec.exe" -ArgumentList "/i `"$rewriteFile`" /qn /norestart")

    Start-Sleep -Seconds 20
    Log-Info "Triggered installation..."

    $returnCode = $process.ExitCode;

    if ($returnCode -eq 0 -or $returnCode -eq 3010)
    {
        Log-Success "[OK]`n"
    }
    else
    {
        Log-Error "IIS URL Rewrite Module 2.1 installation failed. Aborting..."
        Log-Warning "MSI source: $rewriteFile"
        exit -10
    }
}

<#
.SYNOPSIS
Validate and exit if minimum defined PowerShell version is not available.
Usage:
    ValidatePSVersion
#>

function ValidatePSVersion
{
    [System.Version]$minVer = "4.0"

    Log-Info "Verifying the PowerShell version to run the script..."

    if ($PSVersionTable.PSVersion)
    {
        $global:PsVer = $PSVersionTable.PSVersion
    }
    
    If ($global:PsVer -lt $minVer)
    {
        Log-Error "PowerShell version $minVer, or higher is required. Current PowerShell version is $global:PsVer. Aborting..."
        exit -11;
    }
    else
    {
        Log-Success "[OK]`n"
    }
}

<#
.SYNOPSIS
Validate and exit if PS process in not 64-bit as few cmdlets like install-windowsfeature is not available in 32-bit.
Usage:
    ValidateIsPowerShell64BitProcess
#>

function ValidateIsPowerShell64BitProcess
{
    Log-Info "Verifying the PowerShell is running in 64-bit mode..."

    # This check is valid for PowerShell 3.0 and higher only.
    if ([Environment]::Is64BitProcess)
    {
        Log-Success "[OK]`n"
    }
    else
    {
        Log-Warning "PowerShell process is found to be 32-bit. While launching PowerShell do not select Windows PowerShell (x86) and rerun the script. Aborting..."        
        Log-Error "[Failed]`n"
        exit -11;
    }
}

<#
.SYNOPSIS
Ensure IIS backend services are in running state. During IISReset they can remain in stop state as well.
Usage:
    StartIISServices
#>

function StartIISServices
{
    Log-Info "Ensuring critical services for Azure Migrate appliance configuration manager are running..."

    Start-service -Name WAS
    Start-service -Name W3SVC

    if ($?)
    {
        Log-Success "[OK]`n"
    } else 
    {
        Log-Error "Failed to start services WAS/W3SVC. Aborting..."
        Log-Warning "Manually start the services WAS and W3SVC"
        exit -12
    }
}

<#
.SYNOPSIS
Set Trusted Hosts in the host\current machine.
Usage:
    SetTrustedHosts
#>

function SetTrustedHosts
{
    $currentList = Get-Item WSMan:\localhost\Client\TrustedHosts
    Log-Info "The current value of $($currentList.Name) = $($currentList.Value)"

    if ($SkipSettingTrustedHost)
    {
        $global:WarningCount++
        Log-Warning "Warning #$global:WarningCount : Skipping setting Trusted Host List for WinRM. Please manually set Trusted Host list to Windows hosts/servers that will be accessed from this appliance/machine."
        Log-Warning "Not specifying workgroup machines in the Trusted Host list leads to Validate-Operation failure during onboarding through Azure Migrate appliance configuration manager. Continuing...`n"

        return
    }

    if($currentList -ne $null)
    {
        # Need to add a better than *. * will be used for preview.
        $list = "*"
        Log-Info "Adding $($list) as trusted hosts to the current host machine..."

        Set-Item WSMan:\localhost\Client\TrustedHosts $list.ToString() -Force

        if ($?)
        {
            Log-Success "[OK]`n"
        }
        else
        {
            Log-Error "Failure in adding trusted hosts. Aborting..."
            Log-Warning "Please use -SkipSettingTrustedHost flag to skip this step and rerun this script."
            exit -13
        }
    }
    else
    {
            Log-Error "Unable to get trusted host list. Aborting..."
            exit -13
    }
}

<#
.SYNOPSIS
Uninstall IE as IE is not compatible with Azure Migrate WebApp. IE cannot be uninstalled like regular programs.
Usage:
    UninstallInternetExplorer
#>

function UninstallInternetExplorer
{
    if ((Get-WindowsOptionalFeature -Online -FeatureName "Internet-Explorer-Optional-amd64").State -eq "Disabled")
    {
        Log-Info "Internet Explorer has already been uninstalled. Skipping uninstallation..."
        Log-Success "[OK]`n"

        return
    }
  
    do
    {
        Log-Error "The latest Azure Migrate appliance configuration manager is not supported on Internet Explorer 11 or lower."
        Log-Error "You can either uninstall Internet Explorer using this script and open the appliance URL https://$machineHostName`:44368 on any other browser except Internet Explorer."
        Log-Warning "Do you want to remove Internet Explorer browser from this machine now? This will force a machine reboot immediately. Press [Y] to continue with the uninstallation or [N] to manually uninstall Internet Explorer..."
        $userChoice = Read-Host
    }while ("y", "n" -NotContains $userChoice.ToLower()) 

    if ($userChoice.ToLower() -eq "n")
    {
        Log-Error "Skipping IE uninstallation...`n"
        Log-Success "Installation completed successfully."
        Log-Warning "User Action Required - Remove Internet Explorer as the default browser and then launch Azure Migrate appliance configuration manager using the shortcut placed on the desktop."
    }
    else
    {
        dism /online /disable-feature /featurename:Internet-Explorer-Optional-amd64 /NoRestart

        # Restart the machine
        Log-Warning "Restarting the machine $machineHostName in 60 seconds.`n"
        shutdown -r -t 60 -f
        Log-Success "Installation completed successfully."
        Log-Error '[Restarting in 60 seconds. To abort restart execute "shutdown /a" - Not Recommended]'
    }

    # Exit the script as restart is pending.
    exit 0
}

<#
.SYNOPSIS
Install New Edge Browser.
Usage:
    InstallEdgeBrowser
#>

function InstallEdgeBrowser
{    
    $edgeInstalleExeFilePath = "$PSScriptRoot\MicrosoftEdgeSetup.exe"

    if( Test-Path -path "HKLM:\SOFTWARE\Clients\StartMenuInternet\Microsoft Edge")
    {
        Log-Info "New Edge browser is already installed. Skipping downloading & installation. Continuing..."
        Log-Success "[OK]`n"
        return
    }

    do
    {
        Log-Error "The latest Azure Migrate appliance configuration manager is not supported on Internet Explorer 11 or lower so you would need to install any of these browsers to continue with appliance configuration manager -Edge (latest version), Chrome (latest version), Firefox (latest version)."
        Log-Warning "Do you want to install New Edge browser now (highly recomended)? [Y/N] - You may skip Edge browser installation (select 'N') in case you are already using a browser from the above list."
        $userChoice = Read-Host

    }while ("y", "n" -NotContains $userChoice.ToLower()) 

    if ($userChoice.ToLower() -eq "n")
    {
        Log-Error "Skipping New Edge installation..."
        Log-Warning "User Action Required - Install the Edge browser manually or use a browser from the above list.`n"
        return
    }
    else
    {
        $regHive = "HKLM:\Software\Policies\Microsoft\Edge"
        if ( -not (Test-Path $regHive))
        {                
            New-Item -Path $regHive -Force
        }
        New-ItemProperty -Path $regHive -Name "HideFirstRunExperience" -PropertyType "dword" -Value 1 -Force

        Start-Process -FilePath $edgeInstalleExeFilePath -Wait

        $edgeShortCut = "$env:SystemDrive`\Users\Public\Desktop\Microsoft Edge.lnk"
        remove-item -Path $edgeShortCut -Force

        Log-Info "Set New Edge browser as default manually to open https://$machineHostName`:44368 next time`n"
    }
}

<#
.SYNOPSIS
Detect presets for various parameters.
Usage:
    DetectPresets
#>

function DetectPresets
{
    $presetFilePath = "$PSScriptRoot\Scenario.json"
    $expectedScenarioList = "HyperV","Physical","VMware"
    $expectedCloudList = "Public","USGov","USNat"
    $expectedScaleOutType = "Migration","MigrationDependencyMapping"
    $scenarioText = "Physical or other virtualization (AWS, GCP, Xen, etc.)"
    $scenarioSubText = "Unknown"
    $scenarioSubTextForHyperV   = "discover and assess Hyper-V VMs"
    $scenarioSubTextForPhysical = "discover and assess $scenarioText"
    $scenarioSubTextForVMware   = "discover, assess and migrate VMware VMs"

    if ($UpgradeAgents)
    {
        $presetFilePath = $ApplianceJsonFilePath
    }
    else
    {
        if ($Scenario)
        {
            switch($Scenario)
            {
                "HyperV"
                {
                    $scenarioText = "Hyper-V"
                    $scenarioSubText = $scenarioSubTextForHyperV
                }

                "Physical"
                {
                    #$scenarioText = 
                    $scenarioSubText = $scenarioSubTextForPhysical
                }

                "VMware"
                {
                    $scenarioText = "VMware"
                    $scenarioSubText = $scenarioSubTextForVMware
                }
             }

            Log-Warning "Scenario to be installed\upgraded selected through overide parameter: $scenarioText`n"
            $global:SelectedFabricType = $Scenario
        }

        if ($Cloud)
        {
            Log-Warning "Cloud to be used selected through overide parameter: $Cloud`n"
            $global:SelectedCloud = $Cloud
        }
        <#
        if ($ScaleOut)
        {
            #Log-Warning "ScaleOut type to be used selected through overide parameter: $ScaleOut`n"
            $global:SelectedScaleOut = $ScaleOut
        }
        #>
    }

    if([System.IO.File]::Exists($presetFilePath))
    {
        $jsonContent = Get-Content $presetFilePath | Out-String | ConvertFrom-Json

        if(-Not $Scenario)
        {
            if ($jsonContent.FabricType -eq "VMwareV2" -or $jsonContent.FabricType -eq "VMware")
            {
                # Special Handling for VMware as fabrictype in Appliance.json is VMwareV2.
                $global:SelectedFabricType = "VMware"
                $scenarioText = "VMware"
                $scenarioSubText = $scenarioSubTextForVMware

                Log-Info "Scenario to be installed\upgraded: $scenarioText`n"
            }
            elseif($expectedScenarioList -contains $jsonContent.FabricType)
            {
                $global:SelectedFabricType = $jsonContent.FabricType

                if ($jsonContent.FabricType -eq "Physical")
                {
                    #$scenarioText =
                    $scenarioSubText = $scenarioSubTextForPhysical
                }
                elseif ($jsonContent.FabricType -eq "HyperV")
                {             
                    $scenarioText = $jsonContent.FabricType
                    $scenarioSubText = $scenarioSubTextForHyperV                    
                }

                Log-Info "Scenario to be installed\upgraded: $scenarioText`n"
            }
        }

        if(-Not $Cloud)
        {
            if($expectedCloudList -contains $jsonContent.Cloud)
            {
                $global:SelectedCloud = $jsonContent.Cloud
                Log-Info "Cloud to be used: $global:SelectedCloud`n"
            }
        }

        <#
        if(-Not $ScaleOut)
        {
            if($expectedScaleOutType -contains $jsonContent.ScaleOut)
            {
                $global:SelectedScaleOut = $jsonContent.ScaleOut
                Log-Success "ScaleOut type to be used: $global:SelectedScaleOut`n"
            }
            else
            {
                Log-Info "This will not be setup as a ScaleOut appliance.`n"
            }
        }
        #>
    }
    
    if ($global:SelectedFabricType -eq $global:DefaultStringVal -or $global:SelectedCloud -eq $global:DefaultStringVal)
    {
        Log-Error "Mandatory parameter(s) not found. Aborting..."
        Log-Warning "Please execute the script again by providing the mandatory parameter -Scenario with value [VMware/Physical/HyperV] and optional parameter -Cloud value [Public/USGov/USNat]. For example: .\AzureMigrateInstaller.ps1 -Scenario VMware -Cloud Public."
        exit -15
    }

    <#
    # Special handling for scale out as it is not supported for scenarios other than VMware currently
    if ($global:SelectedFabricType  -ne "VMware" -and $global:SelectedScaleOut -ne "None")
    {
        $global:SelectedScaleOut = "None"
        Log-Error "ScaleOut parameter is currently applicable for VMware scenario only. Ignoring ScaleOut parameter value."
        Log-Warning "Press Enter key to continue:"
        Read-Host
    }
    #>

    do
    {
       Log-Success "This deployment will help you $scenarioSubText to an Azure Migrate project for $global:SelectedCloud cloud."
       Log-Warning "If this is not the desired appliance scenario, you need to execute the script again by providing the parameter -Scenario with value [VMware/Physical/HyperV] and -Cloud value [Public/USGov/USNat]. For example: .\AzureMigrateInstaller.ps1 -Scenario VMware -Cloud Public"
       Log-Warning "Enter [Y] to continue with deployment of $scenarioText appliance or [N] to abort:"
       $userChoice = Read-Host

    }while ("y", "n" -NotContains $userChoice.ToLower()) 

    if ($userChoice.ToLower() -eq "n")
    {
       Log-Error "Aborting installation..."
       exit 0
    }
}

<#
.SYNOPSIS
Install Gateway service.
Usage:
    InstallGatewayService -$gatewayPackagerPath "$$gatewayPackagerPath" -$MSIInstallLogName "ToDo"
#>

function InstallGatewayService
{ 
    param(
        [string] $gatewayPackagerPath,
        [string] $MSIInstallLogName
    )

    $extractCmd = "`"$gatewayPackagerPath`"" + " /q /x:`"$PSScriptRoot`""
    
    Log-Info "Extracting and Installing Gateway Service..."
    
    Invoke-Expression "& $extractCmd"
    Start-Sleep -Seconds 5

    $process = (Start-Process -Wait -Passthru -FilePath "$PSScriptRoot\GATEWAYSETUPINSTALLER.EXE" -ArgumentList "CommandLineInstall ")
    $returnCode = $process.ExitCode;

    if ($returnCode -eq 0 -or $returnCode -eq 3010) 
    {
        Log-Success "[OK]`n"
    }
    else
    {
        Log-Error "Gateway service installation failed. Aborting..."
        Log-Warning "Please refer to http://www.msierrors.com/ to get details about the error code: $returnCode. Please share the installation log file NONAME while contacting Microsoft Support."
        exit -16
    }
}

try
{
    $Error.Clear()

    # Validate PowerShell, OS version and user role.
    ValidatePSVersion
    ValidateIsPowerShell64BitProcess
    ValidateOSVersion

    # Detect the presets to know what needs to be installed.
    DetectPresets

    # Detect and take user intent to cleanup previous installation if found.
    DetectAndCleanupPreviousInstallation

    # Add the required registry keys.
    AddingRegistryKeys

    # Enable IIS.
    EnableIIS

    # Download and Install rewrite module.
    InstallRewriteModule
    
    # Set trusted hosts to machine.
    SetTrustedHosts
 
    # Install Discovery, Assessment and MIgration agents based on the scenario .
    switch($global:SelectedFabricType)
    {
        HyperV
        {
            $ApplianceJsonFileData.FabricType="HyperV"
            InstallMSI -MSIFilePath "$PSScriptRoot\$HyperVDiscoveryServiceMSI" `
                -MSIInstallLogName $DiscoveryServiceMSILog
            InstallMSI -MSIFilePath "$PSScriptRoot\$HyperVAssessmentServiceMSI" `
                -MSIInstallLogName $AssessmentServiceMSILog
        }
        Physical
        {
            $ApplianceJsonFileData.FabricType="Physical"
            InstallMSI -MSIFilePath "$PSScriptRoot\$ServerDiscoveryServiceMSI" `
                -MSIInstallLogName $DiscoveryServiceMSILog
            InstallMSI -MSIFilePath "$PSScriptRoot\$ServerAssessmentServiceMSI" `
                -MSIInstallLogName $AssessmentServiceMSILog
        }
        VMware
        {
            $ApplianceJsonFileData.FabricType="VMwareV2"
            $ApplianceJsonFileData.VddkInstallerFolder="%programfiles%\\VMware\\VMware Virtual Disk Development Kit";

            #if ($global:SelectedScaleOut -eq "None")
            if($true)
            {
                InstallMSI -MSIFilePath "$PSScriptRoot\$VMwareDiscoveryServiceMSI" `
                    -MSIInstallLogName $DiscoveryServiceMSILog
                InstallMSI -MSIFilePath "$PSScriptRoot\$VMwareAssessmentServiceMSI" `
                    -MSIInstallLogName $AssessmentServiceMSILog

                InstallMSI -MSIFilePath "$PSScriptRoot\$DraMsiName" `
                    -MSIInstallLogName $DraMsiLog
            }

            # LogFilePath needs to be added.
            InstallGatewayService "$PSScriptRoot\$GatewayExeName" ""
        }
        default
        {
            Log-Error "Unexpected Scenario selected:$.global:SelectedFabricType. Aborting..."
            Log-Warning "Please retry the script with -Scenario parameter."
            exit -20
        }
    }

    # Install Appliance Configuration Manager
    $ApplianceJsonFileData.Cloud    = $global:SelectedCloud
    #$ApplianceJsonFileData.ScaleOut = $global:SelectedScaleOut
    CreateJsonFile -JsonFileData $ApplianceJsonFileData -JsonFilePath $ApplianceJsonFilePath
    InstallMSI -MSIFilePath "$PSScriptRoot\$WebAppMSI" -MSIInstallLogName $WebAppMSILog
 
    # Install Agent updater.
    $AutoUpdaterJsonFileData.Cloud  = $global:SelectedCloud
    CreateJsonFile -JsonFileData $AutoUpdaterJsonFileData -JsonFilePath $AutoUpdaterJsonFilePath
    InstallMSI -MSIFilePath "$PSScriptRoot\$AutoUpdaterMSI" -MSIInstallLogName $AutoUpdaterMSILog

    # Custom script for IIS bindings and launch UI.
    CreateApplianceVersionFile

    # Ensure critical services for WebApp are in running state.
    StartIISServices

    # Execute WebBinding scripts
    if (-Not (Test-Path -Path "$PSScriptRoot\WebBinding.ps1" -PathType Any))
    {
        Log-Error "Script file not found: `"$PSScriptRoot\WebBinding.ps1`". Aborting..."
        Log-Warning "Please download the package again and retry."
        exit -9
    }
    else
    {
        Log-Info "Running powershell script `"$PSScriptRoot\WebBinding.ps1`"..." 
        & "$PSScriptRoot\WebBinding.ps1" | Out-Null
        if ($?)
        {
            Log-Success "[OK]`n"
        }
        else
        {
            Log-Error "Script execution failed. Aborting..."
            Log-Warning "Please download the package again and retry."
            exit -9
        }
    }

    # Execute SetRegistryForTrustedSites scripts
    if (-Not (Test-Path -Path "$PSScriptRoot\SetRegistryForTrustedSites.ps1" -PathType Any))
    {
        Log-Error "Script file not found: `"$PSScriptRoot\SetRegistryForTrustedSites.ps1`". Aborting..."
        Log-Warning "Please download the package again and retry."
        exit -9
    }
    else
    {
        Log-Info "Running powershell script `"$PSScriptRoot\SetRegistryForTrustedSites.ps1`" with argument '-LaunchApplication $false'..." 
        & "$PSScriptRoot\SetRegistryForTrustedSites.ps1" -LaunchApplication $false | Out-Null
        
        if ($?)
        {
            Log-Success "[OK]`n"
        }
        else
        {
            Log-Error "Script execution failed. Aborting..."
            Log-Warning "Please download the package again and retry."
            exit -9
        }
    }

    # Install Edge Browser and uninstall IE
    InstallEdgeBrowser
    UninstallInternetExplorer

    if ($global:ReuseScenario -eq 1)
    {
        do
        {
            $global:WarningCount++
            Log-Warning "Warning #$global:WarningCount : Please manually clear browser cache before proceeding further.`nProceed [Y] or exit[N] the script now as browser cache hasn't been cleared."            
            $userChoice = Read-Host
        }while ("y", "n" -NotContains $userChoice.ToLower()) 

        if ($userChoice.ToLower() -eq "n")
        {
            Log-Warning "Installation completed. Use the shortcut on desktop to launch `"Azure Migrate appliance configuration manager`" once the browser cache has been manually cleared."
            exit 0  
        }
        else
        {
            Log-Success "Installation completed successfully. Launching Azure Migrate appliance configuration manager to start the onboarding process..."
        }
    }

    if ($global:WarningCount -gt 0)
    {
        Log-Warning "Please review the $global:WarningCount warning(s) hit during script execution and take manual corrective action as suggested in the warning(s)."        
    }

    Log-Info "Launching Azure Migrate appliance configuration manager..."
    Start $DefaultURL
}
catch
{
    Log-Error "Script execution failed with error $_.Exception.Message"
    Log-Error "Error Record: $_.Exception.ErrorRecord"
    Log-Error "Exception caught:  $_.Exception"
    Log-Warning "Retry the script after resolving the issue(s) or contact Microsoft Support."
    exit -1
}
# SIG # Begin signature block
# MIIjhgYJKoZIhvcNAQcCoIIjdzCCI3MCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCE9XJE21jBSO6b
# ptNsygNzieanSBr+Wcmk/fng3CUbcaCCDXYwggX0MIID3KADAgECAhMzAAABhk0h
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
# /Xmfwb1tbWrJUnMTDXpQzTGCFWYwghViAgEBMIGVMH4xCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNp
# Z25pbmcgUENBIDIwMTECEzMAAAGGTSF1oNkHviwAAAAAAYYwDQYJYIZIAWUDBAIB
# BQCgga4wGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEO
# MAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIGZwb0F1K6R+4UJCboTbwy3S
# Q44QkXUNfRbbo7xtJIIsMEIGCisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8A
# cwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEB
# BQAEggEAkTl9qUC/BO7hQ15LLML8U73b5w3LXPJBLyDPnJp8Bhf25Os1afrbhcKK
# /7es2muLMBZUCUxe6aBL6kru0blKWrCil6luUZv/8wOnT2zojMxefelDUW9rF4f+
# LHAm0R7C1ncuV6/Lds/Cq6xDl5mYdX1xbExjtkB7C8rKtTFaCfgXfPnJCMI80Pet
# brPAzqUDso6EFocWrn5vHhmQIDzlxjp5ImpLne99I9bfeCZqep5/sks4iyX34Isa
# SILpamf6YowWfKJ0zNMIsE+Yn9rmn6t5cM36jcyNjB96c2u5GKEVJmVH3ZwJlfom
# 7yZgFwvHNffr2AUzjZM9gyTr0bULKqGCEvAwghLsBgorBgEEAYI3AwMBMYIS3DCC
# EtgGCSqGSIb3DQEHAqCCEskwghLFAgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFUBgsq
# hkiG9w0BCRABBKCCAUMEggE/MIIBOwIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFl
# AwQCAQUABCCmtLLA/6qMsV+gjOOUZqmsYPaYLOZd6OfAZ/jxo8seowIGX2D5wbW1
# GBIyMDIwMDkyNDE5NTEyMy41MlowBIACAfSggdSkgdEwgc4xCzAJBgNVBAYTAlVT
# MRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKTAnBgNVBAsTIE1pY3Jvc29mdCBPcGVy
# YXRpb25zIFB1ZXJ0byBSaWNvMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjpGN0E2
# LUUyNTEtMTUwQTElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2Vydmlj
# ZaCCDkQwggT1MIID3aADAgECAhMzAAABJYvei2xyJjHdAAAAAAElMA0GCSqGSIb3
# DQEBCwUAMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYD
# VQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAk
# BgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMB4XDTE5MTIxOTAx
# MTQ1OFoXDTIxMDMxNzAxMTQ1OFowgc4xCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpX
# YXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQg
# Q29ycG9yYXRpb24xKTAnBgNVBAsTIE1pY3Jvc29mdCBPcGVyYXRpb25zIFB1ZXJ0
# byBSaWNvMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjpGN0E2LUUyNTEtMTUwQTEl
# MCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZTCCASIwDQYJKoZI
# hvcNAQEBBQADggEPADCCAQoCggEBANB7H2N2YFvs4cnBJiYxSitk3ABy/xXLfpOU
# m7NxXHsb6UWq3bONY4yVI4ySbVegC4nxVnlKEF50ANcMYMrEc1mEu7cRbzHmi38g
# 6TqLMtOUAW28hc6DNez8do4zvZccrKQxkcB0v9+lm0BIzk9qWaxdfg6XyVeSb2NH
# nkrnoLur36ENT7a2MYdoTVlaVpuU1RcGFpmC0IkJ3rRTJm+Ajv+43Nxp+PT9XDZt
# qK32cMBV3bjK39cJmcdjfJftmweMi4emyX4+kNdqLUPB72nSvIJmyX1I4wd7G0gd
# 72qVNu1Zgnxa1Yugf10QxDFUueY88M5WYGPstmFKOLfw31WnP8UCAwEAAaOCARsw
# ggEXMB0GA1UdDgQWBBTzqsrlByb5ATk0FcYI8iIIF0Mk+DAfBgNVHSMEGDAWgBTV
# YzpcijGQ80N7fEYbxTNoWoVtVTBWBgNVHR8ETzBNMEugSaBHhkVodHRwOi8vY3Js
# Lm1pY3Jvc29mdC5jb20vcGtpL2NybC9wcm9kdWN0cy9NaWNUaW1TdGFQQ0FfMjAx
# MC0wNy0wMS5jcmwwWgYIKwYBBQUHAQEETjBMMEoGCCsGAQUFBzAChj5odHRwOi8v
# d3d3Lm1pY3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY1RpbVN0YVBDQV8yMDEwLTA3
# LTAxLmNydDAMBgNVHRMBAf8EAjAAMBMGA1UdJQQMMAoGCCsGAQUFBwMIMA0GCSqG
# SIb3DQEBCwUAA4IBAQCTHFk8YSAiACGypk1NmTnxXW9CInmNrbEeXlOoYDofCPlK
# KguDcVIuJOYZX4G0WWlhS2Sd4HiOtmy42ky19tMx0bun/EDIhW3C9edNeoqUIPVP
# 0tyv3ilV53McYnMvVNg1DJkkGi4J/OSCTNxw64U595Y9+cxOIjlQFbk52ajIc9BY
# NIYehuhbV1Mqpd4m25UNNhsdMqzjON8IEwWObKVG7nZmmLP70wF5GPiIB6i7QX/f
# G8jN6mggqBRYJn2aZWJYSRXAK1MZtXx4rvcp4QTS18xT9hjZSagY9zxjBu6sMR96
# V6Atb5geR+twYAaV+0Kaq0504t6CEugbRRvH8HuxMIIGcTCCBFmgAwIBAgIKYQmB
# KgAAAAAAAjANBgkqhkiG9w0BAQsFADCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgT
# Cldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29m
# dCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFJvb3QgQ2VydGlmaWNh
# dGUgQXV0aG9yaXR5IDIwMTAwHhcNMTAwNzAxMjEzNjU1WhcNMjUwNzAxMjE0NjU1
# WjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQD
# Ex1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDCCASIwDQYJKoZIhvcNAQEB
# BQADggEPADCCAQoCggEBAKkdDbx3EYo6IOz8E5f1+n9plGt0VBDVpQoAgoX77Xxo
# SyxfxcPlYcJ2tz5mK1vwFVMnBDEfQRsalR3OCROOfGEwWbEwRA/xYIiEVEMM1024
# OAizQt2TrNZzMFcmgqNFDdDq9UeBzb8kYDJYYEbyWEeGMoQedGFnkV+BVLHPk0yS
# wcSmXdFhE24oxhr5hoC732H8RsEnHSRnEnIaIYqvS2SJUGKxXf13Hz3wV3WsvYpC
# TUBR0Q+cBj5nf/VmwAOWRH7v0Ev9buWayrGo8noqCjHw2k4GkbaICDXoeByw6ZnN
# POcvRLqn9NxkvaQBwSAJk3jN/LzAyURdXhacAQVPIk0CAwEAAaOCAeYwggHiMBAG
# CSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBTVYzpcijGQ80N7fEYbxTNoWoVtVTAZ
# BgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTALBgNVHQ8EBAMCAYYwDwYDVR0TAQH/
# BAUwAwEB/zAfBgNVHSMEGDAWgBTV9lbLj+iiXGJo0T2UkFvXzpoYxDBWBgNVHR8E
# TzBNMEugSaBHhkVodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpL2NybC9wcm9k
# dWN0cy9NaWNSb29DZXJBdXRfMjAxMC0wNi0yMy5jcmwwWgYIKwYBBQUHAQEETjBM
# MEoGCCsGAQUFBzAChj5odHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpL2NlcnRz
# L01pY1Jvb0NlckF1dF8yMDEwLTA2LTIzLmNydDCBoAYDVR0gAQH/BIGVMIGSMIGP
# BgkrBgEEAYI3LgMwgYEwPQYIKwYBBQUHAgEWMWh0dHA6Ly93d3cubWljcm9zb2Z0
# LmNvbS9QS0kvZG9jcy9DUFMvZGVmYXVsdC5odG0wQAYIKwYBBQUHAgIwNB4yIB0A
# TABlAGcAYQBsAF8AUABvAGwAaQBjAHkAXwBTAHQAYQB0AGUAbQBlAG4AdAAuIB0w
# DQYJKoZIhvcNAQELBQADggIBAAfmiFEN4sbgmD+BcQM9naOhIW+z66bM9TG+zwXi
# qf76V20ZMLPCxWbJat/15/B4vceoniXj+bzta1RXCCtRgkQS+7lTjMz0YBKKdsxA
# QEGb3FwX/1z5Xhc1mCRWS3TvQhDIr79/xn/yN31aPxzymXlKkVIArzgPF/UveYFl
# 2am1a+THzvbKegBvSzBEJCI8z+0DpZaPWSm8tv0E4XCfMkon/VWvL/625Y4zu2Jf
# mttXQOnxzplmkIz/amJ/3cVKC5Em4jnsGUpxY517IW3DnKOiPPp/fZZqkHimbdLh
# nPkd/DjYlPTGpQqWhqS9nhquBEKDuLWAmyI4ILUl5WTs9/S/fmNZJQ96LjlXdqJx
# qgaKD4kWumGnEcua2A5HmoDF0M2n0O99g/DhO3EJ3110mCIIYdqwUB5vvfHhAN/n
# MQekkzr3ZUd46PioSKv33nJ+YWtvd6mBy6cJrDm77MbL2IK0cs0d9LiFAR6A+xuJ
# KlQ5slvayA1VmXqHczsI5pgt6o3gMy4SKfXAL1QnIffIrE7aKLixqduWsqdCosnP
# GUFN4Ib5KpqjEWYw07t0MkvfY3v1mYovG8chr1m1rtxEPJdQcdeh0sVV42neV8HR
# 3jDA/czmTfsNv11P6Z0eGTgvvM9YBS7vDaBQNdrvCScc1bN+NR4Iuto229Nfj950
# iEkSoYIC0jCCAjsCAQEwgfyhgdSkgdEwgc4xCzAJBgNVBAYTAlVTMRMwEQYDVQQI
# EwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3Nv
# ZnQgQ29ycG9yYXRpb24xKTAnBgNVBAsTIE1pY3Jvc29mdCBPcGVyYXRpb25zIFB1
# ZXJ0byBSaWNvMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjpGN0E2LUUyNTEtMTUw
# QTElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZaIjCgEBMAcG
# BSsOAwIaAxUARdMv4VBtzYb7cxde8hEpWvahcKeggYMwgYCkfjB8MQswCQYDVQQG
# EwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQg
# VGltZS1TdGFtcCBQQ0EgMjAxMDANBgkqhkiG9w0BAQUFAAIFAOMXVUwwIhgPMjAy
# MDA5MjQyMTI2MzZaGA8yMDIwMDkyNTIxMjYzNlowdzA9BgorBgEEAYRZCgQBMS8w
# LTAKAgUA4xdVTAIBADAKAgEAAgIjMgIB/zAHAgEAAgIRrDAKAgUA4ximzAIBADA2
# BgorBgEEAYRZCgQCMSgwJjAMBgorBgEEAYRZCgMCoAowCAIBAAIDB6EgoQowCAIB
# AAIDAYagMA0GCSqGSIb3DQEBBQUAA4GBAKSaGvDLoUvp6elTFYBvRCbJNCk+9zDe
# 4Au0PUW+tx6PjVoBvNxGUUMkspeJVXzow6c0fxPXrFIMUU8IvvBwmPNBzpPinN9U
# zFuWhCnWiXFhHsTs3aYpyLr+vvWsVrm9Bp4TSLZQYMjebkdkt3LTbR7e8leHDnRY
# cqApx0vblccsMYIDDTCCAwkCAQEwgZMwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgT
# Cldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29m
# dCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENB
# IDIwMTACEzMAAAEli96LbHImMd0AAAAAASUwDQYJYIZIAWUDBAIBBQCgggFKMBoG
# CSqGSIb3DQEJAzENBgsqhkiG9w0BCRABBDAvBgkqhkiG9w0BCQQxIgQgs/9cMqa8
# uCYcAdyzHHrijTVlkh+ECjxbSo4O5WTsQXMwgfoGCyqGSIb3DQEJEAIvMYHqMIHn
# MIHkMIG9BCBd38ayLm8wX/qJfYIOH5V+YvlG+poWQXCW6LKN70H3DjCBmDCBgKR+
# MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdS
# ZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMT
# HU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAABJYvei2xyJjHdAAAA
# AAElMCIEIP3tlJFpeqjy+JV0XBQf8pZBvANjZD581rby1axsB5lPMA0GCSqGSIb3
# DQEBCwUABIIBAHU86qifCYuWzOZfLqUcz0SXwUhoFRETINUlE++oZIqpRrHCC0rG
# MsNXlWGOynIYh9CkoDow+K1242CFqrmiq7pGjXXvqdHXSKx//UuP29rzWtp+bQtP
# xFltYh0YA0QrP86NeGIMgqObzrAYXo1wPBcQW9/hhUjKrPk4WmDsWAcUi/q/qPkI
# 9WXzM7fe4WobKrDj092Wroh4aHGJTQPbqNp7Jb6Q4bUjHI8GdzLoy0gZ5yEY5HRT
# zOGm7we3T9b9Vg5apjVMEu2xtsCk8dqBTvPb5tj1r5UAenkfxQcpHHar8gEjWfb0
# U1bqEbifC5zsPTF0M4s00aMHYGXv8zIaVPk=
# SIG # End signature block
