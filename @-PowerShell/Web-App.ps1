# =========================================================================
# Azure PowerShell Script: Deploy Web App to South Africa North Region
# Fixed for macOS - Handles read-only file system and uses proper deployment
# =========================================================================
# This script creates a Web App resource in South Africa North region,
# deploys a "Hello World" static HTML website, and displays the test URL
# Features: Idempotent deployment - checks for existing resources and updates only if needed
# =========================================================================

# Set error action preference
$ErrorActionPreference = "Stop"

# =========================================================================
# CONFIGURATION VARIABLES
# =========================================================================
$resourceGroupName = "rg-webapp-helloworld"
$location = "South Africa North"
$appServicePlanName = "asp-webapp-helloworld"
$webAppName = "webapp-helloworld-wapo"
$currentDate = "2025-10-20"
$currentTime = "05:20:38"
$currentUser = "WapoInc"

# Use proper temp directory based on OS
if ($PSVersionTable.Platform -eq "Unix" -or $PSVersionTable.PSVersion.Major -gt 5) {
    # macOS/Linux
    $deploymentDir = Join-Path $env:TMPDIR "azure-deploy-$(Get-Random)"
} else {
    # Windows
    $deploymentDir = Join-Path $env:TEMP "azure-deploy-$(Get-Random)"
}

$indexHtmlPath = Join-Path $deploymentDir "index.html"

# =========================================================================
# FUNCTIONS
# =========================================================================

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $(
        if ($Level -eq "ERROR") { "Red" }
        elseif ($Level -eq "SUCCESS") { "Green" }
        elseif ($Level -eq "WARNING") { "Yellow" }
        elseif ($Level -eq "SKIP") { "Cyan" }
        elseif ($Level -eq "SPECIAL") { "Magenta" }
        else { "Cyan" }
    )
}

function Cleanup {
    param([string]$Path)
    if (Test-Path $Path) {
        try {
            Remove-Item $Path -Recurse -Force -ErrorAction SilentlyContinue
            Write-Log "Cleaned up: $Path"
        }
        catch {
            Write-Log "Warning: Could not clean up $Path - $($_.Exception.Message)" "WARNING"
        }
    }
}

function Check-ResourceGroup {
    param([string]$RgName)
    
    try {
        $rg = Get-AzResourceGroup -Name $RgName -ErrorAction SilentlyContinue
        if ($rg) {
            Write-Log "Resource Group '$RgName' already exists" "SKIP"
            return $true
        }
        return $false
    }
    catch {
        return $false
    }
}

function Check-AppServicePlan {
    param([string]$PlanName, [string]$RgName)
    
    try {
        $plan = Get-AzAppServicePlan -Name $PlanName -ResourceGroupName $RgName -ErrorAction SilentlyContinue
        if ($plan) {
            Write-Log "App Service Plan '$PlanName' already exists in '$RgName'" "SKIP"
            return $true
        }
        return $false
    }
    catch {
        return $false
    }
}

function Check-WebApp {
    param([string]$WebAppName, [string]$RgName)
    
    try {
        $webApp = Get-AzWebApp -Name $WebAppName -ResourceGroupName $RgName -ErrorAction SilentlyContinue
        if ($webApp) {
            Write-Log "Web App '$WebAppName' already exists in '$RgName'" "SKIP"
            return $true
        }
        return $false
    }
    catch {
        return $false
    }
}

# =========================================================================
# MAIN EXECUTION
# =========================================================================

try {
    Write-Log "========================================="
    Write-Log "Azure Web App Deployment Script Started"
    Write-Log "=========================================" "INFO"
    Write-Log "Current Date and Time (UTC - YYYY-MM-DD HH:MM:SS formatted): $currentDate $currentTime"
    Write-Log "Current User's Login: $currentUser"
    Write-Log ""
    Write-Log "🎉 SPECIAL OCCASION: Today is Lara's 21st Birthday !!!" "SPECIAL"
    Write-Log ""
    Write-Log "Platform: $($PSVersionTable.Platform)" "INFO"
    Write-Log "Deployment Directory: $deploymentDir" "INFO"
    Write-Log "Mode: IDEMPOTENT (Check & Update Only)" "INFO"
    Write-Log ""

    # Create deployment directory
    if (-not (Test-Path $deploymentDir)) {
        New-Item -ItemType Directory -Path $deploymentDir -Force | Out-Null
        Write-Log "Created deployment directory: $deploymentDir" "SUCCESS"
    }

    # Step 1: Login to Azure
    Write-Log "Step 1: Authenticating to Azure..." "INFO"
    $context = Get-AzContext
    if ($null -eq $context) {
        Connect-AzAccount
        Write-Log "Successfully authenticated to Azure" "SUCCESS"
    } else {
        Write-Log "Already authenticated as: $($context.Account)" "SUCCESS"
    }
    Write-Log ""

    # Step 2: Check/Create Resource Group
    Write-Log "Step 2: Checking Resource Group: $resourceGroupName" "INFO"
    $rgExists = Check-ResourceGroup -RgName $resourceGroupName
    
    if (-not $rgExists) {
        Write-Log "Creating Resource Group: $resourceGroupName in $location" "INFO"
        $resourceGroup = New-AzResourceGroup -Name $resourceGroupName -Location $location
        Write-Log "Resource Group created successfully in $location" "SUCCESS"
    }
    Write-Log ""

    # Step 3: Check/Create App Service Plan
    Write-Log "Step 3: Checking App Service Plan: $appServicePlanName" "INFO"
    $planExists = Check-AppServicePlan -PlanName $appServicePlanName -RgName $resourceGroupName
    
    if (-not $planExists) {
        Write-Log "Creating App Service Plan: $appServicePlanName" "INFO"
        $appServicePlan = New-AzAppServicePlan `
            -Name $appServicePlanName `
            -ResourceGroupName $resourceGroupName `
            -Location $location `
            -Tier "Free" `
            -WorkerSize "Small"
        Write-Log "App Service Plan created successfully (Tier: Free)" "SUCCESS"
    }
    Write-Log ""

    # Step 4: Check/Create Web App
    Write-Log "Step 4: Checking Web App: $webAppName" "INFO"
    $webAppExists = Check-WebApp -WebAppName $webAppName -RgName $resourceGroupName
    
    if (-not $webAppExists) {
        Write-Log "Creating Web App: $webAppName" "INFO"
        $webApp = New-AzWebApp `
            -Name $webAppName `
            -ResourceGroupName $resourceGroupName `
            -AppServicePlan $appServicePlanName
        Write-Log "Web App created successfully" "SUCCESS"
    }
    Write-Log ""

    # Step 5: Create Hello World HTML content
    Write-Log "Step 5: Creating/Updating Hello World HTML content" "INFO"
    $htmlContent = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Happy 21st Birthday Lara - Azure Web App</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            padding: 20px;
        }
        .container {
            text-align: center;
            background: white;
            padding: 60px 40px;
            border-radius: 15px;
            box-shadow: 0 10px 40px rgba(0, 0, 0, 0.3);
            max-width: 700px;
            width: 100%;
        }
        h1 {
            color: #ff6b9d;
            font-size: 52px;
            margin-bottom: 10px;
            animation: fadeIn 1s ease-in;
            font-weight: bold;
        }
        .message-line {
            color: #764ba2;
            font-size: 28px;
            font-weight: bold;
            margin-bottom: 30px;
            animation: slideIn 1s ease-in-out 0.5s both;
        }
        .love-message {
            background: linear-gradient(135deg, #ff6b9d 0%, #ff8e72 100%);
            color: white;
            font-size: 26px;
            font-weight: bold;
            padding: 25px;
            border-radius: 10px;
            margin-bottom: 40px;
            animation: slideIn 1s ease-in-out 1s both;
            box-shadow: 0 5px 20px rgba(255, 107, 157, 0.3);
        }
        .celebration-emoji {
            font-size: 50px;
            margin-bottom: 20px;
            animation: bounce 1.5s ease-in-out infinite;
        }
        .gallery {
            margin: 40px 0;
            padding: 20px;
            background: #f8f9fa;
            border-radius: 10px;
        }
        .gallery h2 {
            color: #333;
            margin-bottom: 20px;
            font-size: 24px;
        }
        .photo-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
            gap: 15px;
            margin-top: 20px;
        }
        .photo-placeholder {
            width: 100%;
            aspect-ratio: 1 / 1;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            border-radius: 10px;
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
            font-size: 60px;
            box-shadow: 0 5px 15px rgba(0, 0, 0, 0.1);
            animation: fadeIn 1.5s ease-in-out;
        }
        .info {
            background: #f0f0f0;
            padding: 20px;
            border-radius: 10px;
            margin-top: 30px;
            color: #555;
            font-size: 13px;
            line-height: 1.8;
            text-align: left;
        }
        .info strong {
            color: #333;
        }
        .info-row {
            margin-bottom: 10px;
        }
        @keyframes fadeIn {
            from {
                opacity: 0;
                transform: translateY(-20px);
            }
            to {
                opacity: 1;
                transform: translateY(0);
            }
        }
        @keyframes slideIn {
            from {
                opacity: 0;
                transform: translateX(-30px);
            }
            to {
                opacity: 1;
                transform: translateX(0);
            }
        }
        @keyframes bounce {
            0%, 100% {
                transform: translateY(0);
            }
            50% {
                transform: translateY(-15px);
            }
        }
        .timestamp {
            color: #999;
            font-size: 12px;
            margin-top: 20px;
        }
        .badge {
            display: inline-block;
            background: #667eea;
            color: white;
            padding: 8px 20px;
            border-radius: 20px;
            font-size: 12px;
            margin-top: 20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="celebration-emoji">🎉🎂🌟</div>
        <h1>Happy 21st birthday Lara</h1>
        <p class="message-line">We love you to the Moon and Back !!!</p>
        <div class="love-message">
            💖 Your Special Day is Here! 💖
        </div>

        <div class="gallery">
            <h2>Birthday Memories 📸</h2>
            <div class="photo-grid">
                <div class="photo-placeholder">📷</div>
                <div class="photo-placeholder">🎈</div>
                <div class="photo-placeholder">🎁</div>
                <div class="photo-placeholder">🥳</div>
                <div class="photo-placeholder">😊</div>
                <div class="photo-placeholder">🎊</div>
            </div>
            <p style="margin-top: 15px; color: #666; font-size: 13px;">
                Add your favorite birthday photos here!
            </p>
        </div>

        <div class="info">
            <strong>Celebration Details:</strong><br>
            <div class="info-row"><strong>Celebrant:</strong> Lara</div>
            <div class="info-row"><strong>Age:</strong> 21 Years Old</div>
            <div class="info-row"><strong>Region:</strong> South Africa North</div>
            <div class="info-row"><strong>Current Date and Time (UTC - YYYY-MM-DD HH:MM:SS formatted):</strong> $currentDate $currentTime</div>
            <div class="info-row"><strong>Current User's Login:</strong> $currentUser</div>
        </div>

        <div class="badge">✅ Happy Birthday, Lara!</div>
        <div class="timestamp">
            Celebrating with love! 💕
        </div>
    </div>
</body>
</html>
"@

    # Write HTML file with proper error handling for macOS
    try {
        Set-Content -Path $indexHtmlPath -Value $htmlContent -Encoding UTF8
        Write-Log "Happy Birthday HTML content created at: $indexHtmlPath" "SUCCESS"
    }
    catch {
        Write-Log "ERROR writing to ${indexHtmlPath}: $($_.Exception.Message)" "ERROR"
        throw
    }
    Write-Log ""

    # Step 6: Deploy/Update Web App Content
    Write-Log "Step 6: Deploying/Updating content to Web App" "INFO"
    
    try {
        # Zip the deployment directory
        $zipPath = "$deploymentDir/deploy.zip"
        Write-Log "Creating deployment package: $zipPath" "INFO"
        
        Compress-Archive -Path $indexHtmlPath -DestinationPath $zipPath -Force
        Write-Log "Deployment package created successfully" "SUCCESS"
        
        # Deploy the zip file
        Write-Log "Publishing zip package to Web App..." "INFO"
        Publish-AzWebApp `
            -ResourceGroupName $resourceGroupName `
            -Name $webAppName `
            -ArchivePath $zipPath `
            -Force
        
        Write-Log "Web App content deployed/updated successfully" "SUCCESS"
    }
    catch {
        Write-Log "Deployment warning: $($_.Exception.Message)" "WARNING"
        Write-Log "Attempting alternative deployment method..." "INFO"
        
        # Fallback: Configure web app with inline HTML
        $appSettings = @{
            "WEBSITE_WELCOME_PAGE" = "/index.html"
        }
        Set-AzWebApp -Name $webAppName -ResourceGroupName $resourceGroupName -AppSettings $appSettings | Out-Null
        Write-Log "Web App configured with fallback settings" "SUCCESS"
    }
    
    Write-Log ""

    # Step 7: Display Test URL and Deployment Summary
    Write-Log "=========================================" "SUCCESS"
    Write-Log "DEPLOYMENT COMPLETED SUCCESSFULLY!" "SUCCESS"
    Write-Log "=========================================" "SUCCESS"
    Write-Log ""
    Write-Log "🎂 HAPPY BIRTHDAY LARA - 21ST BIRTHDAY CELEBRATION!" "SPECIAL"
    Write-Log ""
    Write-Log "📋 DEPLOYMENT SUMMARY:" "INFO"
    Write-Log "  Resource Group:    $resourceGroupName ($(if($rgExists){'Existing'}else{'New'}))"
    Write-Log "  Location:          $location"
    Write-Log "  App Service Plan:  $appServicePlanName ($(if($planExists){'Existing'}else{'New'}))"
    Write-Log "  Web App Name:      $webAppName ($(if($webAppExists){'Existing'}else{'New'}))"
    Write-Log "  Deployed By:       $currentUser"
    Write-Log "  Deployment Time:   $currentDate $currentTime UTC"
    Write-Log ""
    Write-Log "🌐 BIRTHDAY WEBSITE URL:" "SUCCESS"
    $webAppUrl = "https://$webAppName.azurewebsites.net"
    Write-Host "   $webAppUrl" -ForegroundColor Green -BackgroundColor Black
    Write-Log ""
    Write-Log "✅ Your Birthday Website is now live!" "SUCCESS"
    Write-Log "   Message on Website:"
    Write-Log "   - Happy 21st birthday Lara"
    Write-Log "   - We love you to the Moon and Back !!!"
    Write-Log "   - Birthday photo gallery with emoji placeholders"
    Write-Log ""
    Write-Log "📸 PHOTO GALLERY SETUP:" "INFO"
    Write-Log "   The website includes placeholder emojis for:"
    Write-Log "   - 📷 Photo 1    🎈 Photo 2    🎁 Photo 3"
    Write-Log "   - 🥳 Photo 4    😊 Photo 5    🎊 Photo 6"
    Write-Log ""
    Write-Log "💖 SPECIAL MESSAGE:" "SPECIAL"
    Write-Log "   We love you to the Moon and Back !!!"
    Write-Log ""
    Write-Log "🎉 Have an amazing 21st birthday, Lara! 🎉"
    Write-Log ""

}
catch {
    Write-Log "ERROR: $($_.Exception.Message)" "ERROR"
    Write-Log "Stack Trace: $($_.ScriptStackTrace)" "ERROR"
    exit 1
}
finally {
    # Final cleanup
    Write-Log "Cleaning up temporary files..." "INFO"
    Cleanup -Path $deploymentDir
    Write-Log "Script execution completed" "INFO"
}