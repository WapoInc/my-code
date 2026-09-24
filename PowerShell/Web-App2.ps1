# =========================================================================
# Azure PowerShell Script: Deploy Birthday Web App (Idempotent)
# =========================================================================
# - Reuses existing RG / Plan / Web App if present
# - Copies local birthday image (prefers .jpeg, falls back to .jpg)
# - Deploys HTML + image
# =========================================================================

$ErrorActionPreference = "Stop"

# ---------------------------
# CONFIGURATION
# ---------------------------
$resourceGroupName   = "rg-webapp-helloworld"
$location            = "South Africa North"
$appServicePlanName  = "asp-webapp-helloworld"
$webAppName          = "webapp-helloworld-wapo"
$currentDate         = "2025-10-20"
# $currentTime         = "07:23:27"
# $currentUser         = "WapoInc"

# Local image directory & candidate filenames
$localImageDir       = "/Users/vinceresente/Library/CloudStorage/OneDrive-Personal/Github/My-Repos/my-code-vmr/@-PowerShell"
$imagePriorityList   = @("lara-birthday.jpeg","lara-birthday.jpg")  # .jpeg preferred
$selectedImageFile   = $null

# Temp deployment workspace
if ($PSVersionTable.Platform -eq "Unix" -or $PSVersionTable.PSVersion.Major -gt 5) {
    $deploymentDir = Join-Path $env:TMPDIR "azure-deploy-$(Get-Random)"
} else {
    $deploymentDir = Join-Path $env:TEMP "azure-deploy-$(Get-Random)"
}
$indexHtmlPath = Join-Path $deploymentDir "index.html"

# Will set once we know which file exists
$deploymentImagePath = $null

# ---------------------------
# LOGGING FUNCTION
# ---------------------------
function Write-Log {
    param([string]$Message,[string]$Level="INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "ERROR"   {"Red"}
        "SUCCESS" {"Green"}
        "WARNING" {"Yellow"}
        "SKIP"    {"Cyan"}
        "SPECIAL" {"Magenta"}
        default   {"Cyan"}
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

# ---------------------------
# CLEANUP
# ---------------------------
function Cleanup {
    param([string]$Path)
    if (Test-Path $Path) {
        Remove-Item $Path -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ---------------------------
# EXISTENCE CHECKS
# ---------------------------
function Check-ResourceGroup {
    param($Name)
    return [bool](Get-AzResourceGroup -Name $Name -ErrorAction SilentlyContinue)
}
function Check-AppServicePlan {
    param($Name,$Rg)
    return [bool](Get-AzAppServicePlan -Name $Name -ResourceGroupName $Rg -ErrorAction SilentlyContinue)
}
function Check-WebApp {
    param($Name,$Rg)
    return [bool](Get-AzWebApp -Name $Name -ResourceGroupName $Rg -ErrorAction SilentlyContinue)
}

# ---------------------------
# IMAGE SELECTION & COPY
# ---------------------------
function Select-And-CopyImage {
    param(
        [string]$SourceDir,
        [string[]]$Candidates,
        [string]$DestinationDir
    )
    foreach ($file in $Candidates) {
        $full = Join-Path $SourceDir $file
        if (Test-Path $full) {
            Write-Log "Found image candidate: $file" "SUCCESS"
            $dest = Join-Path $DestinationDir $file
            Copy-Item -Path $full -Destination $dest -Force
            if (Test-Path $dest) {
                $srcSize  = (Get-Item $full).Length
                $dstSize  = (Get-Item $dest).Length
                if ($srcSize -eq $dstSize) {
                    Write-Log "Copied image ($file) -> integrity OK ($srcSize bytes)" "SUCCESS"
                } else {
                    Write-Log "Copied image ($file) size mismatch SRC=$srcSize DST=$dstSize (continuing)" "WARNING"
                }
                return $file
            } else {
                Write-Log "Copy failed for $file" "ERROR"
            }
        } else {
            Write-Log "Image not found: $file" "SKIP"
        }
    }
    return $null
}

# ---------------------------
# MAIN
# ---------------------------
try {
    Write-Log "================================================="
    Write-Log "Birthday Web App Deployment Starting"
    Write-Log "================================================="
    Write-Log "Mode: Idempotent"
    Write-Log "Local Image Directory: $localImageDir"
    Write-Log "Preferred Image Order: $($imagePriorityList -join ', ')"
    Write-Log ""

    if (-not (Test-Path $deploymentDir)) {
        New-Item -ItemType Directory -Path $deploymentDir | Out-Null
        Write-Log "Created deployment workspace: $deploymentDir" "SUCCESS"
    }

    # Authenticate (reuse context if available)
    if (-not (Get-AzContext -ErrorAction SilentlyContinue)) {
        Write-Log "Authenticating to Azure..." "INFO"
        Connect-AzAccount | Out-Null
        Write-Log "Authenticated" "SUCCESS"
    } else {
        Write-Log "Using existing Azure context" "SUCCESS"
    }

    # Resource Group
    $rgExists = Check-ResourceGroup $resourceGroupName
    if ($rgExists) {
        Write-Log "Resource Group exists: $resourceGroupName" "SKIP"
    } else {
        Write-Log "Creating Resource Group: $resourceGroupName" "INFO"
        New-AzResourceGroup -Name $resourceGroupName -Location $location | Out-Null
        Write-Log "Resource Group created" "SUCCESS"
    }

    # App Service Plan
    $planExists = Check-AppServicePlan $appServicePlanName $resourceGroupName
    if ($planExists) {
        Write-Log "App Service Plan exists: $appServicePlanName" "SKIP"
    } else {
        Write-Log "Creating App Service Plan: $appServicePlanName" "INFO"
        New-AzAppServicePlan -Name $appServicePlanName -ResourceGroupName $resourceGroupName -Location $location -Tier "Free" -WorkerSize "Small" | Out-Null
        Write-Log "App Service Plan created" "SUCCESS"
    }

    # Web App
    $webAppExists = Check-WebApp $webAppName $resourceGroupName
    if ($webAppExists) {
        Write-Log "Web App exists: $webAppName" "SKIP"
    } else {
        Write-Log "Creating Web App: $webAppName" "INFO"
        New-AzWebApp -Name $webAppName -ResourceGroupName $resourceGroupName -AppServicePlan $appServicePlanName | Out-Null
        Write-Log "Web App created" "SUCCESS"
    }

    # Image selection
    Write-Log "Selecting image (prefers .jpeg)..." "INFO"
    $selectedImageFile = Select-And-CopyImage -SourceDir $localImageDir -Candidates $imagePriorityList -DestinationDir $deploymentDir
    if ($selectedImageFile) {
        $deploymentImagePath = $selectedImageFile
    } else {
        Write-Log "No image found. Page will show placeholder." "WARNING"
    }

    # HTML creation
    Write-Log "Building HTML page..." "INFO"
    $imgTag = if ($deploymentImagePath) {
        "<img src=""$deploymentImagePath"" alt=""Birthday Image"" onerror=""this.style.display='none';this.parentElement.innerHTML='<div class=\\'photo-placeholder\\'>Image unavailable</div>'"">"
    } else {
        "<div class='photo-placeholder'>No image found</div>"
    }

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8" />
<title>Happy 21st Birthday Lara</title>
<meta name="viewport" content="width=device-width,initial-scale=1" />
<style>
    *{margin:0;padding:0;box-sizing:border-box}
    body{
        font-family:'Segoe UI',Tahoma,sans-serif;
        background:linear-gradient(135deg,#667eea 0%,#764ba2 100%);
        min-height:100vh;
        display:flex;
        justify-content:center;
        align-items:center;
        padding:24px;
        animation:bgPulse 6s ease-in-out infinite;
    }
    .card{
        width:100%;
        max-width:820px;
        background:#fff;
        border-radius:22px;
        padding:48px 44px;
        box-shadow:0 25px 70px -12px rgba(0,0,0,.35);
        position:relative;
        overflow:hidden;
        border:3px solid #ff6b9d;
        animation:cardIn .9s cubic-bezier(.25,.8,.25,1);
    }
    h1{
        font-size:clamp(2.2rem,5vw,3.6rem);
        text-align:center;
        background:linear-gradient(90deg,#ff6b9d,#ff8e72,#ffd93d);
        -webkit-background-clip:text;
        color:transparent;
        letter-spacing:2px;
        margin-bottom:14px;
        animation:fadeDown .9s ease;
    }
    .tagline{
        text-align:center;
        font-size:clamp(1.1rem,2.6vw,1.8rem);
        font-weight:600;
        color:#5a3f92;
        margin-bottom:38px;
        animation:fadeUp .9s ease .15s both;
    }
    .photo-shell{
        position:relative;
        border:5px solid #ff6b9d;
        border-radius:20px;
        overflow:hidden;
        height:480px;
        max-height:60vh;
        display:flex;
        justify-content:center;
        align-items:center;
        background:#f4f4f6;
        box-shadow:0 18px 48px -10px rgba(0,0,0,.35);
        animation:slideIn 1s ease .25s both;
    }
    .photo-shell img{
        width:100%;
        height:100%;
        object-fit:cover;
        transition:transform .8s ease, filter .6s ease;
        filter:brightness(.94) saturate(1.05);
    }
    .photo-shell:hover img{
        transform:scale(1.04);
        filter:brightness(1.05) saturate(1.15);
    }
    .photo-placeholder{
        font-size:1.1rem;
        color:#777;
        text-align:center;
        padding:24px;
        line-height:1.5;
    }
    .footer-badge{
        margin:46px auto 0;
        display:inline-block;
        padding:16px 38px;
        background:linear-gradient(135deg,#ff6b9d 0%,#ff8e72 50%,#ffd93d 100%);
        color:#fff;
        border-radius:32px;
        font-weight:700;
        font-size:1.05rem;
        letter-spacing:.5px;
        box-shadow:0 10px 30px -8px rgba(255,107,157,.55);
        position:relative;
        animation:fadeIn .9s ease .55s both;
        cursor:default;
        user-select:none;
        text-shadow:1px 2px 4px rgba(0,0,0,.25);
    }
    .date-line{
        margin-top:18px;
        text-align:center;
        font-size:.75rem;
        letter-spacing:1px;
        opacity:.6;
        animation:fadeIn .9s ease .7s both;
    }
    /* Confetti */
    .confetti{
        position:fixed;
        top:-12px;
        width:12px;
        height:12px;
        background:#ff6b9d;
        opacity:.85;
        animation:confettiFall linear forwards;
        pointer-events:none;
        z-index:50;
        will-change:transform;
        border-radius:2px;
    }
    /* Animations */
    @keyframes bgPulse {
        0%,100%{filter:hue-rotate(0deg)}
        50%{filter:hue-rotate(25deg)}
    }
    @keyframes cardIn {
        from{opacity:0;transform:translateY(45px) scale(.92)}
        to{opacity:1;transform:translateY(0) scale(1)}
    }
    @keyframes fadeDown {
        from{opacity:0;transform:translateY(-30px)}
        to{opacity:1;transform:translateY(0)}
    }
    @keyframes fadeUp {
        from{opacity:0;transform:translateY(30px)}
        to{opacity:1;transform:translateY(0)}
    }
    @keyframes slideIn {
        from{opacity:0;transform:translateX(-55px) rotateY(18deg)}
        to{opacity:1;transform:translateX(0) rotateY(0)}
    }
    @keyframes fadeIn {
        from{opacity:0} to{opacity:1}
    }
    @keyframes confettiFall {
        0%{transform:translateY(0) rotate(0deg)}
        100%{transform:translateY(100vh) rotate(720deg);opacity:0}
    }
    @media (max-width:680px){
        .card{padding:34px 26px}
        .photo-shell{height:380px}
    }
    @media (max-width:480px){
        .card{padding:30px 20px;border-width:2px}
        .photo-shell{height:300px}
        h1{font-size:2.2rem}
        .tagline{font-size:1.05rem}
        .footer-badge{padding:14px 28px;font-size:.9rem}
    }
</style>
</head>
<body>
    <div class="card">
        <h1>Happy 21st Birthday Lara</h1>
        <div class="tagline">We love you to the Moon and Back !!!</div>
        <div class="photo-shell">
            $imgTag
        </div>
        <span class="footer-badge">✨ Love & Blessings ✨</span>
        <div class="date-line">Today • $currentDate</div>
    </div>
<script>
(function confetti(){
    const colors=["#ff6b9d","#ffd93d","#ff8e72","#667eea","#764ba2"];
    for(let i=0;i<42;i++){
        const c=document.createElement('div');
        c.className='confetti';
        c.style.left=Math.random()*100+'vw';
        c.style.background=colors[Math.floor(Math.random()*colors.length)];
        c.style.animationDuration=(2.8+Math.random()*1.8)+'s';
        c.style.animationDelay=(Math.random()*0.6)+'s';
        c.style.transform='translateY(0) rotate('+ (Math.random()*360)+'deg)';
        document.body.appendChild(c);
        setTimeout(()=>c.remove(),5000);
    }
})();
</script>
</body>
</html>
"@

    Set-Content -Path $indexHtmlPath -Value $html -Encoding UTF8
    Write-Log "HTML created: $indexHtmlPath" "SUCCESS"

    # Assemble deployment file list
    $files = @($indexHtmlPath)
    if ($deploymentImagePath) {
        $files += (Join-Path $deploymentDir $deploymentImagePath)
        Write-Log "Including image: $deploymentImagePath" "SUCCESS"
    } else {
        Write-Log "No image included in this deployment" "WARNING"
    }

    # Zip & deploy
    $zipPath = Join-Path $deploymentDir "deploy.zip"
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
    Write-Log "Creating package..." "INFO"
    Compress-Archive -Path $files -DestinationPath $zipPath -Force
    Write-Log "Package size: $((Get-Item $zipPath).Length) bytes" "INFO"

    Write-Log "Publishing to Web App..." "INFO"
    Publish-AzWebApp -ResourceGroupName $resourceGroupName -Name $webAppName -ArchivePath $zipPath -Force
    Write-Log "Deployment complete" "SUCCESS"

    $url = "https://$webAppName.azurewebsites.net"
    Write-Log "=================================================" "SUCCESS"
    Write-Log " LIVE URL: $url" "SUCCESS"
    Write-Log " Image Deployed: $deploymentImagePath" "SUCCESS"
    Write-Log "=================================================" "SUCCESS"

}
catch {
    Write-Log "ERROR: $($_.Exception.Message)" "ERROR"
    Write-Log "StackTrace: $($_.ScriptStackTrace)" "ERROR"
    exit 1
}
finally {
    Cleanup $deploymentDir
}