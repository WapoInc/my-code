# Instructors :
# Vince Resente
# Warren du Toit
####
# Final version used in the workshop
# Requires Az PowerShell module
# Install-Module -Name Az -AllowClobber -Scope CurrentUser

Connect-AzAccount
# Set-AzContext -SubscriptionId "your sub id"

# Capture start time in GMT+2
$StartTime = Get-Date
$StartTimestamp = $StartTime

Write-Host "=======================================" -ForegroundColor Cyan
Write-Host "Deployment Started: $StartTimestamp " -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host ""

# Set variables
$Location = "southafricanorth"
$ResourceGroup = "POC-MEA-Comm-Day-Student"
$OnpremVnet = "onprem-vnet"
$AzureVnet = "azure-vnet"

$OnpremVnetPrefix = "192.168.0.0/22"
$OnpremVnetPrefix2 = "192.168.4.0/22"
$OnpremVnetPrefix3 = "192.168.8.0/22"

$OnpremSubnetPrefix = "192.168.1.0/24"
$OnpremSubnet4Prefix = "192.168.4.0/24"
$OnpremGatewaySubnetPrefix = "192.168.0.0/27"

$AzureVnetPrefix = "10.70.0.0/22"
$AzureSubnetPrefix = "10.70.1.0/24"
$AzureGatewaySubnetPrefix = "10.70.0.0/27"
$AzureFirewallSubnetPrefix = "10.70.3.0/26"

$OnpremVm = "onprem-vm1"
$OnpremVm2 = "onprem-vm2"
$AzureVm = "azure-vm1"

$Username = "adminazure"
$Password = "P@ssw0rd123!"
$SharedKey = "AzureSharedKey123"
$SharedKey2 = "AzureSharedKey321"

$FirewallName = "AzFW"
$FirewallPipName = "AzFW-Pub-IP"
$FirewallPolicyName = "AzFW-Policy-01"

# Boot Diagnostics Storage Account
$BootDiagStorageAccountName = "bootdiag" + (Get-Random -Minimum 10000 -Maximum 99999)

Write-Host "=============================================================================" -ForegroundColor Yellow
Write-Host "Creating Resource Group..." -ForegroundColor Yellow
Write-Host "=============================================================================" -ForegroundColor Yellow

$rgResult = New-AzResourceGroup `
  -Name $ResourceGroup `
  -Location $Location

Write-Host ""
Write-Host "=============================================================================" -ForegroundColor Green
Write-Host "✓ Resource Group Created Successfully!" -ForegroundColor Green
Write-Host "=============================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Resource Group Details:" -ForegroundColor Cyan
Write-Host "  • Name:         $($rgResult.ResourceGroupName)" -ForegroundColor White
Write-Host "  • Location:     $($rgResult.Location)" -ForegroundColor White
Write-Host "  • Provisioning: $($rgResult.ProvisioningState)" -ForegroundColor White
Write-Host "  • Resource ID:  $($rgResult.ResourceId)" -ForegroundColor Gray
Write-Host "=============================================================================" -ForegroundColor Green
Write-Host ""

# # ============================================================================
# # BOOT DIAGNOSTICS STORAGE ACCOUNT CREATION
# # ============================================================================
Write-Host "=============================================================================" -ForegroundColor Yellow
Write-Host "Creating Storage Account for Boot Diagnostics..." -ForegroundColor Yellow
Write-Host "=============================================================================" -ForegroundColor Yellow

$storageAccount = New-AzStorageAccount `
  -ResourceGroupName $ResourceGroup `
  -Name $BootDiagStorageAccountName `
  -Location $Location `
  -SkuName Standard_LRS `
  -Kind StorageV2

Write-Host ""
Write-Host "=============================================================================" -ForegroundColor Green
Write-Host "✓ Storage Account Created Successfully!" -ForegroundColor Green
Write-Host "=============================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Storage Account Details:" -ForegroundColor Cyan
Write-Host "  • Name:          $($storageAccount.StorageAccountName)" -ForegroundColor White
Write-Host "  • SKU:           $($storageAccount.Sku.Name)" -ForegroundColor White
Write-Host "  • Kind:          $($storageAccount.Kind)" -ForegroundColor White
Write-Host "  • Resource ID:   $($storageAccount.Id)" -ForegroundColor Gray
Write-Host "=============================================================================" -ForegroundColor Green
Write-Host ""

# ============================================================================
# VNET AND SUBNET CREATION
# ============================================================================
Write-Host "=============================================================================" -ForegroundColor Yellow
Write-Host "Creating Virtual Networks and Subnets..." -ForegroundColor Yellow
Write-Host "=============================================================================" -ForegroundColor Yellow

# Create onprem VNet with BOTH address prefixes and subnets (WITHOUT AzureBastionSubnet)
$onpremSubnet = New-AzVirtualNetworkSubnetConfig -Name "onprem-hub" -AddressPrefix $OnpremSubnetPrefix
$onpremGwSubnet = New-AzVirtualNetworkSubnetConfig -Name "GatewaySubnet" -AddressPrefix $OnpremGatewaySubnetPrefix
$onpremSubnet4 = New-AzVirtualNetworkSubnetConfig -Name "Subnet-4" -AddressPrefix $OnpremSubnet4Prefix

New-AzVirtualNetwork `
  -ResourceGroupName $ResourceGroup `
  -Location $Location `
  -Name $OnpremVnet `
  -AddressPrefix @($OnpremVnetPrefix, $OnpremVnetPrefix2) `
  -Subnet @($onpremSubnet, $onpremGwSubnet, $onpremSubnet4) | Out-Null

# Create Azure VNet with subnets (WITHOUT AzureBastionSubnet)
$azureSubnet = New-AzVirtualNetworkSubnetConfig -Name "azure-hub" -AddressPrefix $AzureSubnetPrefix
$azureGwSubnet = New-AzVirtualNetworkSubnetConfig -Name "GatewaySubnet" -AddressPrefix $AzureGatewaySubnetPrefix
$azureFwSubnet = New-AzVirtualNetworkSubnetConfig -Name "AzureFirewallSubnet" -AddressPrefix $AzureFirewallSubnetPrefix

$azureVnetObj = New-AzVirtualNetwork `
  -ResourceGroupName $ResourceGroup `
  -Location $Location `
  -Name $AzureVnet `
  -AddressPrefix $AzureVnetPrefix `
  -Subnet @($azureSubnet, $azureGwSubnet, $azureFwSubnet)

Write-Host "=============================================================================" -ForegroundColor Green
Write-Host "✓ Virtual Networks and Subnets created" -ForegroundColor Green
Write-Host "=============================================================================" -ForegroundColor Green

# ============================================================================
# PUBLIC IP CREATION
# ============================================================================
Write-Host "=============================================================================" -ForegroundColor Yellow
Write-Host "Creating Public IPs..." -ForegroundColor Yellow
Write-Host "=============================================================================" -ForegroundColor Yellow

# Create public IPs for gateways
New-AzPublicIpAddress `
  -ResourceGroupName $ResourceGroup `
  -Name "onprem-gateway-pip" `
  -Location $Location `
  -Sku Standard `
  -AllocationMethod Static | Out-Null

New-AzPublicIpAddress `
  -ResourceGroupName $ResourceGroup `
  -Name "azure-gateway-pip" `
  -Location $Location `
  -Sku Standard `
  -AllocationMethod Static | Out-Null

# Create public IP for Azure Firewall
New-AzPublicIpAddress `
  -ResourceGroupName $ResourceGroup `
  -Name $FirewallPipName `
  -Location $Location `
  -Sku Standard `
  -AllocationMethod Static | Out-Null

Write-Host "=============================================================================" -ForegroundColor Green
Write-Host "✓ Public IPs created" -ForegroundColor Green
Write-Host "=============================================================================" -ForegroundColor Green

# ============================================================================
# AZURE FIREWALL POLICY SECTION
# ============================================================================
Write-Host "=============================================================================" -ForegroundColor Yellow
Write-Host "Creating Azure Firewall Policy..." -ForegroundColor Yellow
Write-Host "=============================================================================" -ForegroundColor Yellow

# Create Azure Firewall Policy (basic policy without rules)
$firewallPolicy = New-AzFirewallPolicy `
  -ResourceGroupName $ResourceGroup `
  -Name $FirewallPolicyName `
  -Location $Location `
  -SkuTier Standard `
  -ThreatIntelMode Alert

Write-Host "=============================================================================" -ForegroundColor Green
Write-Host "✓ Azure Firewall Policy created (no rules configured)" -ForegroundColor Green
Write-Host "=============================================================================" -ForegroundColor Green

# ============================================================================
# AZURE FIREWALL CREATION
# ============================================================================
Write-Host "=============================================================================" -ForegroundColor Yellow
Write-Host "Creating Azure Firewall..." -ForegroundColor Yellow
Write-Host "=============================================================================" -ForegroundColor Yellow

# Get the updated VNet and subnet
$azureVnetObj = Get-AzVirtualNetwork -ResourceGroupName $ResourceGroup -Name $AzureVnet
$firewallPip = Get-AzPublicIpAddress -ResourceGroupName $ResourceGroup -Name $FirewallPipName

# Create Azure Firewall with policy association (NO Log Analytics)
$firewall = New-AzFirewall `
  -ResourceGroupName $ResourceGroup `
  -Name $FirewallName `
  -Location $Location `
  -VirtualNetwork $azureVnetObj `
  -PublicIpAddress $firewallPip `
  -FirewallPolicyId $firewallPolicy.Id

Write-Host "=============================================================================" -ForegroundColor Green
Write-Host "✓ Azure Firewall created and associated with policy" -ForegroundColor Green
Write-Host "=============================================================================" -ForegroundColor Green

# Get the private IP of the Azure Firewall for routing
$FirewallPrivateIp = $firewall.IpConfigurations[0].PrivateIpAddress
$FirewallPublicIp = (Get-AzPublicIpAddress -ResourceGroupName $ResourceGroup -Name $FirewallPipName).IpAddress

Write-Host "=============================================================================" -ForegroundColor Cyan
Write-Host "Azure Firewall IPs:" -ForegroundColor Cyan
Write-Host "  Private IP: $FirewallPrivateIp" -ForegroundColor White
Write-Host "  Public IP: $FirewallPublicIp" -ForegroundColor White
Write-Host "=============================================================================" -ForegroundColor Cyan

# ============================================================================
# AZURE FIREWALL NETWORK RULE CONFIGURATION
# ============================================================================
Write-Host "=============================================================================" -ForegroundColor Yellow
Write-Host "Configuring Azure Firewall Network Rules..." -ForegroundColor Yellow
Write-Host "=============================================================================" -ForegroundColor Yellow

# Create a network rule to allow traffic from on-premises to Azure
$networkRule = New-AzFirewallPolicyNetworkRule `
  -Name "Allow-Onprem-Hub-to-Azure" `
  -Protocol TCP, UDP, ICMP `
  -SourceAddress "192.168.2.0/24" `
  -DestinationAddress "10.70.1.0/24" `
  -DestinationPort "*"

# Create a network rule to allow traffic from on-premises Subnet-4 (192.168.4.0/24) to Azure
$networkRuleSubnet4 = New-AzFirewallPolicyNetworkRule `
  -Name "Allow-Onprem-Subnet4-to-Azure" `
  -Protocol TCP, UDP, ICMP `
  -SourceAddress "192.168.5.0/24" `
  -DestinationAddress "10.70.1.0/24" `
  -DestinationPort "*"

  # ADDITION: Create a network rule to allow traffic from Azure to Onprem (10.70.1.0.0/24) to OnPrem
$networkRuleAzure = New-AzFirewallPolicyNetworkRule `
  -Name "Allow-Azure-to-Onprem-Subnet4" `
  -Protocol TCP, UDP, ICMP `
  -SourceAddress "10.70.1.0/24" `
  -DestinationAddress "192.168.2.0/24,192.168.4.0/24" `
  -DestinationPort "*"

  # Create a network rule to allow traffic from Azure to 0-0-0-0
$networkRuleAzure = New-AzFirewallPolicyNetworkRule `
  -Name "Allow-Azure-to-0-0-0-0" `
  -Protocol TCP, UDP, ICMP `
  -SourceAddress "10.70.1.0/24" `
  -DestinationAddress "0.0.0.0/0" `
  -DestinationPort "*"

# Create a rule collection with the network rule
$networkRuleCollection = New-AzFirewallPolicyFilterRuleCollection `
  -Name "NetworkRuleCollection" `
  -Priority 100 `
  -Rule @($networkRule, $networkRuleSubnet4, $networkRuleAzure) `
  -ActionType Allow

# Create a rule collection group
New-AzFirewallPolicyRuleCollectionGroup `
  -Name "DefaultNetworkRuleCollectionGroup" `
  -Priority 200 `
  -FirewallPolicyName $FirewallPolicyName `
  -ResourceGroupName $ResourceGroup `
  -RuleCollection $networkRuleCollection | Out-Null

Write-Host "✓ Network rules created:" -ForegroundColor Green
Write-Host "   • 192.168.1.0/24 → 10.70.1.0/24 (TCP/UDP/ICMP)" -ForegroundColor Green
Write-Host "   • 192.168.4.0/24 → 10.70.1.0/24 (TCP/UDP/ICMP)" -ForegroundColor Green

Write-Host "=============================================================================" -ForegroundColor Green
Write-Host "✓ Azure Firewall Network Rules configured" -ForegroundColor Green
Write-Host "=============================================================================" -ForegroundColor Green

# ============================================================================
# ROUTE TABLE CONFIGURATION WITH FIREWALL PRIVATE IP
# ============================================================================
Write-Host "=============================================================================" -ForegroundColor Yellow
Write-Host "Creating Route Tables with Azure Firewall Private IP..." -ForegroundColor Yellow
Write-Host "=============================================================================" -ForegroundColor Yellow

# Create Route Table for Azure Hub subnet with Firewall IP and BGP propagation disabled
$routeTable = New-AzRouteTable `
  -Name "azure-subnet-rt" `
  -ResourceGroupName $ResourceGroup `
  -Location $Location `
  -DisableBgpRoutePropagation

# Add route to forward 192.168.1.0/24 traffic to Azure Firewall
Get-AzRouteTable -ResourceGroupName $ResourceGroup -Name "azure-subnet-rt" | `
  Add-AzRouteConfig `
    -Name "route-to-onprem-192-168-1-0" `
    -AddressPrefix "192.168.2.0/24" `
    -NextHopType "VirtualAppliance" `
    -NextHopIpAddress $FirewallPrivateIp | `
  Set-AzRouteTable | Out-Null

# Add route to forward 192.168.4.0/24 traffic to Azure Firewall
Get-AzRouteTable -ResourceGroupName $ResourceGroup -Name "azure-subnet-rt" | `
  Add-AzRouteConfig `
    -Name "route-to-onprem-192-168-4-0" `
    -AddressPrefix "192.168.5.0/24" `
    -NextHopType "VirtualAppliance" `
    -NextHopIpAddress $FirewallPrivateIp | `
  Set-AzRouteTable | Out-Null

# Associate route table with Azure azure-hub subnet
$azureVnetObj = Get-AzVirtualNetwork -ResourceGroupName $ResourceGroup -Name $AzureVnet
$azureSubnetConfig = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $azureVnetObj -Name "azure-hub"
$azureSubnetConfig.RouteTable = $routeTable
Set-AzVirtualNetwork -VirtualNetwork $azureVnetObj | Out-Null

Write-Host "✓ Created azure-hub subnet route table: 192.168.1.0/24 → $FirewallPrivateIp (BGP Propagation: Disabled)" -ForegroundColor Green
Write-Host "✓ Created azure-hub subnet route table: 192.168.4.0/24 → $FirewallPrivateIp (BGP Propagation: Disabled)" -ForegroundColor Green

# Create a second Route Table for Gateway Subnet with BGP propagation disabled
$gatewayRouteTable = New-AzRouteTable `
  -Name "azure-gateway-subnet-rt" `
  -ResourceGroupName $ResourceGroup `
  -Location $Location `
  -DisableBgpRoutePropagation

# Add route for Gateway Subnet
Get-AzRouteTable -ResourceGroupName $ResourceGroup -Name "azure-gateway-subnet-rt" | `
  Add-AzRouteConfig `
    -Name "route-to-hub-subnet" `
    -AddressPrefix "10.70.2.0/24" `
    -NextHopType "VirtualAppliance" `
    -NextHopIpAddress $FirewallPrivateIp | `
  Set-AzRouteTable | Out-Null

# Associate the Gateway Subnet route table to the GatewaySubnet
$azureVnetObj = Get-AzVirtualNetwork -ResourceGroupName $ResourceGroup -Name $AzureVnet
$azureGwSubnetConfig = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $azureVnetObj -Name "GatewaySubnet"
$azureGwSubnetConfig.RouteTable = $gatewayRouteTable
Set-AzVirtualNetwork -VirtualNetwork $azureVnetObj | Out-Null

Write-Host "✓ Created and associated Gateway Subnet route table: 10.70.1.0/24 → $FirewallPrivateIp (BGP Propagation: Disabled)" -ForegroundColor Green

Write-Host "=============================================================================" -ForegroundColor Green
Write-Host "✓ All route tables created with Azure Firewall Private IP" -ForegroundColor Green
Write-Host "✓ BGP Route Propagation disabled on all route tables" -ForegroundColor Green
Write-Host "=============================================================================" -ForegroundColor Green

# ============================================================================
# VIRTUAL MACHINE CREATION WITH BOOT DIAGNOSTICS
# ============================================================================
Write-Host "=============================================================================" -ForegroundColor Yellow
Write-Host "Creating Virtual Machines with Boot Diagnostics in parallel..." -ForegroundColor Yellow
Write-Host "=============================================================================" -ForegroundColor Yellow

# Create VMs in parallel using PowerShell jobs
$vmJobs = @()

$vmJobs += Start-Job -ScriptBlock {
    param($rg, $name, $vnet, $subnet, $user, $pass, $loc, $storageUri)
    
    Import-Module Az.Compute, Az.Network
    
    $SecurePassword = ConvertTo-SecureString $pass -AsPlainText -Force
    $Credential = New-Object System.Management.Automation.PSCredential ($user, $SecurePassword)
    
    $vnetObj = Get-AzVirtualNetwork -ResourceGroupName $rg -Name $vnet
    $subnetObj = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnetObj -Name $subnet
    
    $nic = New-AzNetworkInterface `
      -ResourceGroupName $rg `
      -Location $loc `
      -Name "$name-nic" `
      -SubnetId $subnetObj.Id
    
    $vmConfig = New-AzVMConfig -VMName $name -VMSize "Standard_B2s" | `
      Set-AzVMOperatingSystem -Linux -ComputerName $name -Credential $Credential | `
      Set-AzVMSourceImage -PublisherName "Canonical" -Offer "0001-com-ubuntu-server-jammy" -Skus "22_04-lts-gen2" -Version "latest" | `
      Add-AzVMNetworkInterface -Id $nic.Id | `
      Set-AzVMBootDiagnostic -Enable -ResourceGroupName $rg -StorageAccountName ($storageUri -replace 'https://' -replace '.blob.core.windows.net/')
    
    New-AzVM -ResourceGroupName $rg -Location $loc -VM $vmConfig
} -ArgumentList $ResourceGroup, $OnpremVm, $OnpremVnet, "onprem-hub", $Username, $Password, $Location, $storageAccount.PrimaryEndpoints.Blob


$vmJobs += Start-Job -ScriptBlock {
    param($rg, $name, $vnet, $subnet, $user, $pass, $loc, $storageUri)
    
    Import-Module Az.Compute, Az.Network
    
    $SecurePassword = ConvertTo-SecureString $pass -AsPlainText -Force
    $Credential = New-Object System.Management.Automation.PSCredential ($user, $SecurePassword)
    
    $vnetObj = Get-AzVirtualNetwork -ResourceGroupName $rg -Name $vnet
    $subnetObj = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnetObj -Name $subnet
    
    $nic = New-AzNetworkInterface `
      -ResourceGroupName $rg `
      -Location $loc `
      -Name "$name-nic" `
      -SubnetId $subnetObj.Id
    
    $vmConfig = New-AzVMConfig -VMName $name -VMSize "Standard_B2s" | `
      Set-AzVMOperatingSystem -Linux -ComputerName $name -Credential $Credential | `
      Set-AzVMSourceImage -PublisherName "Canonical" -Offer "0001-com-ubuntu-server-jammy" -Skus "22_04-lts-gen2" -Version "latest" | `
      Add-AzVMNetworkInterface -Id $nic.Id | `
      Set-AzVMBootDiagnostic -Enable -ResourceGroupName $rg -StorageAccountName ($storageUri -replace 'https://' -replace '.blob.core.windows.net/')
    
    New-AzVM -ResourceGroupName $rg -Location $loc -VM $vmConfig
} -ArgumentList $ResourceGroup, $AzureVm, $AzureVnet, "azure-hub", $Username, $Password, $Location, $storageAccount.PrimaryEndpoints.Blob


$vmJobs += Start-Job -ScriptBlock {
    param($rg, $name, $vnet, $subnet, $user, $pass, $loc, $storageUri)
    
    Import-Module Az.Compute, Az.Network
    
    $SecurePassword = ConvertTo-SecureString $pass -AsPlainText -Force
    $Credential = New-Object System.Management.Automation.PSCredential ($user, $SecurePassword)
    
    $vnetObj = Get-AzVirtualNetwork -ResourceGroupName $rg -Name $vnet
    $subnetObj = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnetObj -Name $subnet
    
    $nic = New-AzNetworkInterface `
      -ResourceGroupName $rg `
      -Location $loc `
      -Name "$name-nic" `
      -SubnetId $subnetObj.Id
    
    $vmConfig = New-AzVMConfig -VMName $name -VMSize "Standard_B2s" | `
      Set-AzVMOperatingSystem -Linux -ComputerName $name -Credential $Credential | `
      Set-AzVMSourceImage -PublisherName "Canonical" -Offer "0001-com-ubuntu-server-jammy" -Skus "22_04-lts-gen2" -Version "latest" | `
      Add-AzVMNetworkInterface -Id $nic.Id | `
      Set-AzVMBootDiagnostic -Enable -ResourceGroupName $rg -StorageAccountName ($storageUri -replace 'https://' -replace '.blob.core.windows.net/')
    
    New-AzVM -ResourceGroupName $rg -Location $loc -VM $vmConfig
} -ArgumentList $ResourceGroup, $OnpremVm2, $OnpremVnet, "Subnet-4", $Username, $Password, $Location, $storageAccount.PrimaryEndpoints.Blob

# Wait for all VM jobs to complete
$vmJobs | Wait-Job | Out-Null
$vmJobs | Remove-Job

Write-Host "=============================================================================" -ForegroundColor Green
Write-Host "✓ Virtual Machines created with Boot Diagnostics enabled" -ForegroundColor Green
Write-Host "=============================================================================" -ForegroundColor Green

# ============================================================================
# VPN GATEWAY CREATION (PARALLEL)
# ============================================================================
Write-Host "=============================================================================" -ForegroundColor Yellow
Write-Host "Starting VPN Gateway deployments (this will take 30-45 minutes)..." -ForegroundColor Yellow
Write-Host "=============================================================================" -ForegroundColor Yellow

# Capture gateway deployment start time
$GatewayStartTime = Get-Date

# Create VPN gateways IN PARALLEL using background jobs
$gwJobs = @()

$gwJobs += Start-Job -ScriptBlock {
    param($rg, $loc, $vnetName, $pipName)
    
    Import-Module Az.Network
    
    $vnet = Get-AzVirtualNetwork -ResourceGroupName $rg -Name $vnetName
    $gwSubnet = Get-AzVirtualNetworkSubnetConfig -Name "GatewaySubnet" -VirtualNetwork $vnet
    $pip = Get-AzPublicIpAddress -ResourceGroupName $rg -Name $pipName
    
    $ipConfig = New-AzVirtualNetworkGatewayIpConfig `
      -Name "gwipconfig" `
      -SubnetId $gwSubnet.Id `
      -PublicIpAddressId $pip.Id
    
    New-AzVirtualNetworkGateway `
      -ResourceGroupName $rg `
      -Location $loc `
      -Name "onprem-gateway" `
      -IpConfigurations $ipConfig `
      -GatewayType Vpn `
      -VpnType RouteBased `
      -GatewaySku VpnGw1
} -ArgumentList $ResourceGroup, $Location, $OnpremVnet, "onprem-gateway-pip"

$gwJobs += Start-Job -ScriptBlock {
    param($rg, $loc, $vnetName, $pipName)
    
    Import-Module Az.Network
    
    $vnet = Get-AzVirtualNetwork -ResourceGroupName $rg -Name $vnetName
    $gwSubnet = Get-AzVirtualNetworkSubnetConfig -Name "GatewaySubnet" -VirtualNetwork $vnet
    $pip = Get-AzPublicIpAddress -ResourceGroupName $rg -Name $pipName
    
    $ipConfig = New-AzVirtualNetworkGatewayIpConfig `
      -Name "gwipconfig" `
      -SubnetId $gwSubnet.Id `
      -PublicIpAddressId $pip.Id
    
    New-AzVirtualNetworkGateway `
      -ResourceGroupName $rg `
      -Location $loc `
      -Name "azure-gateway" `
      -IpConfigurations $ipConfig `
      -GatewayType Vpn `
      -VpnType RouteBased `
      -GatewaySku VpnGw1
} -ArgumentList $ResourceGroup, $Location, $AzureVnet, "azure-gateway-pip"

Write-Host "=============================================================================" -ForegroundColor Cyan
Write-Host "VPN Gateway deployments initiated. Waiting for completion..." -ForegroundColor Cyan
Write-Host "=============================================================================" -ForegroundColor Cyan
Write-Host "While waiting, you can:" -ForegroundColor White
Write-Host "  • Check VM connectivity within VNets" -ForegroundColor White
Write-Host "  • Configure firewall rules via Portal" -ForegroundColor White
Write-Host "  • Monitor deployment progress in Azure Portal" -ForegroundColor White
Write-Host "  • View VM boot diagnostics in Azure Portal" -ForegroundColor White
Write-Host "=============================================================================" -ForegroundColor Cyan

# Wait for gateway jobs to complete
$gwJobs | Wait-Job | Out-Null

Write-Host "=============================================================================" -ForegroundColor Green
Write-Host "✓ Both gateway deployments complete" -ForegroundColor Green
Write-Host "=============================================================================" -ForegroundColor Green

$gwJobs | Remove-Job

# Calculate gateway deployment time
$GatewayEndTime = Get-Date
$GatewayDuration = $GatewayEndTime - $GatewayStartTime
$GatewayMinutes = [Math]::Floor($GatewayDuration.TotalMinutes)
$GatewaySeconds = $GatewayDuration.Seconds

Write-Host "=============================================================================" -ForegroundColor Cyan
Write-Host "Gateway deployment took: $($GatewayMinutes)m $($GatewaySeconds)s" -ForegroundColor Cyan
Write-Host "=============================================================================" -ForegroundColor Cyan

# ============================================================================
# VPN CONNECTION CONFIGURATION
# ============================================================================
Write-Host "=============================================================================" -ForegroundColor Yellow
Write-Host "Configuring VPN connections..." -ForegroundColor Yellow
Write-Host "=============================================================================" -ForegroundColor Yellow

# Get public IPs of gateways
$OnpremPublicIp = (Get-AzPublicIpAddress -ResourceGroupName $ResourceGroup -Name "onprem-gateway-pip").IpAddress
$AzurePublicIp = (Get-AzPublicIpAddress -ResourceGroupName $ResourceGroup -Name "azure-gateway-pip").IpAddress

Write-Host "Gateway Public IPs:" -ForegroundColor Cyan
Write-Host "  On-prem: $OnpremPublicIp" -ForegroundColor White
Write-Host "  Azure: $AzurePublicIp" -ForegroundColor White

# Create local network gateways with BOTH onprem address prefixes
$azureLocalGw = New-AzLocalNetworkGateway `
  -ResourceGroupName $ResourceGroup `
  -Name "azure-local-gateway" `
  -Location $Location `
  -GatewayIpAddress $AzurePublicIp `
  -AddressPrefix $AzureVnetPrefix

$onpremLocalGw = New-AzLocalNetworkGateway `
  -ResourceGroupName $ResourceGroup `
  -Name "onprem-local-gateway" `
  -Location $Location `
  -GatewayIpAddress $OnpremPublicIp `
  -AddressPrefix @($OnpremVnetPrefix3)

# Get the VPN gateways
$onpremGateway = Get-AzVirtualNetworkGateway -ResourceGroupName $ResourceGroup -Name "onprem-gateway"
$azureGateway = Get-AzVirtualNetworkGateway -ResourceGroupName $ResourceGroup -Name "azure-gateway"

# Create VPN connections
New-AzVirtualNetworkGatewayConnection `
  -ResourceGroupName $ResourceGroup `
  -Location $Location `
  -Name "onprem-to-azure" `
  -VirtualNetworkGateway1 $onpremGateway `
  -LocalNetworkGateway2 $azureLocalGw `
  -ConnectionType IPsec `
  -SharedKey $SharedKey | Out-Null

New-AzVirtualNetworkGatewayConnection `
  -ResourceGroupName $ResourceGroup `
  -Location $Location `
  -Name "azure-to-onprem" `
  -VirtualNetworkGateway1 $azureGateway `
  -LocalNetworkGateway2 $onpremLocalGw `
  -ConnectionType IPsec `
  -SharedKey $SharedKey2 | Out-Null

Write-Host "=============================================================================" -ForegroundColor Green
Write-Host "✓ VPN connections established" -ForegroundColor Green
Write-Host "=============================================================================" -ForegroundColor Green

# ============================================================================
# DEPLOYMENT SUMMARY
# ============================================================================

# Display configuration summary
Write-Host ""
Write-Host "=============================================================================" -ForegroundColor Cyan
Write-Host "DEPLOYMENT SUMMARY" -ForegroundColor Cyan
Write-Host "=============================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Resource Group: $ResourceGroup" -ForegroundColor White
Write-Host "Location: $Location" -ForegroundColor White
Write-Host ""
Write-Host "Boot Diagnostics Storage Account:" -ForegroundColor Yellow
Write-Host "  • Name: $BootDiagStorageAccountName" -ForegroundColor White
Write-Host "  • SKU: Standard_LRS" -ForegroundColor White
Write-Host "  • Kind: StorageV2" -ForegroundColor White
Write-Host ""
Write-Host "Networks Created:" -ForegroundColor Yellow
Write-Host "  • On-premises VNet: $OnpremVnet" -ForegroundColor White
Write-Host "    - Address Space: $OnpremVnetPrefix, $OnpremVnetPrefix2" -ForegroundColor Gray
Write-Host "    - Subnets: onprem-hub, Subnet-4, GatewaySubnet" -ForegroundColor Gray
Write-Host ""
Write-Host "  • Azure VNet: $AzureVnet" -ForegroundColor White
Write-Host "    - Address Space: $AzureVnetPrefix" -ForegroundColor Gray
Write-Host "    - Subnets: azure-hub, GatewaySubnet, AzureFirewallSubnet" -ForegroundColor Gray
Write-Host ""
Write-Host "Virtual Machines (with Boot Diagnostics):" -ForegroundColor Yellow
Write-Host "  • $OnpremVm (192.168.1.0/24 - onprem-hub) ✓ Boot Diagnostics Enabled" -ForegroundColor White
Write-Host "  • $OnpremVm2 (192.168.4.0/24 - Subnet-4) ✓ Boot Diagnostics Enabled" -ForegroundColor White
Write-Host "  • $AzureVm (10.70.1.0/24 - azure-hub) ✓ Boot Diagnostics Enabled" -ForegroundColor White
Write-Host ""
Write-Host "Azure Firewall:" -ForegroundColor Yellow
Write-Host "  • Name: $FirewallName" -ForegroundColor White
Write-Host "  • Policy: $FirewallPolicyName" -ForegroundColor White
Write-Host "  • Private IP: $FirewallPrivateIp" -ForegroundColor White
Write-Host "  • Public IP: $FirewallPublicIp" -ForegroundColor White
Write-Host "  • Network Rules:" -ForegroundColor White
Write-Host "    - 192.168.1.0/24 → 10.70.1.0/24 (TCP/UDP/ICMP)" -ForegroundColor Cyan
Write-Host "    - 192.168.4.0/24 → 10.70.1.0/24 (TCP/UDP/ICMP)" -ForegroundColor Cyan
Write-Host ""
Write-Host "VPN Gateways:" -ForegroundColor Yellow
Write-Host "  • On-premises Gateway IP: $OnpremPublicIp" -ForegroundColor White
Write-Host "  • Azure Gateway IP: $AzurePublicIp" -ForegroundColor White
Write-Host "  • Connection Status: Configured with shared key" -ForegroundColor Gray
Write-Host ""
Write-Host "Route Tables:" -ForegroundColor Yellow
Write-Host "  • azure-hub subnet UDR (azure-subnet-rt):" -ForegroundColor White
Write-Host "    - Route: 192.168.1.0/24 → $FirewallPrivateIp (Azure Firewall)" -ForegroundColor Cyan
Write-Host "    - Route: 192.168.4.0/24 → $FirewallPrivateIp (Azure Firewall)" -ForegroundColor Cyan
Write-Host "    - Propagate Gateway Routes: No (BGP Propagation Disabled)" -ForegroundColor Magenta
Write-Host "    - Associated to: azure-hub (10.70.1.0/24)" -ForegroundColor Gray
Write-Host ""
Write-Host "  • Gateway Subnet UDR (azure-gateway-subnet-rt):" -ForegroundColor White
Write-Host "    - Route: 10.70.1.0/24 → $FirewallPrivateIp (Azure Firewall)" -ForegroundColor Cyan
Write-Host "    - Propagate Gateway Routes: No (BGP Propagation Disabled)" -ForegroundColor Magenta
Write-Host "    - Associated to: GatewaySubnet (10.70.0.0/27)" -ForegroundColor Gray
Write-Host ""
Write-Host "=============================================================================" -ForegroundColor Cyan

# Capture end time and calculate duration in UTC+2
$EndTime = Get-Date
$EndTimestamp = $EndTime.AddHours(2).ToString("yyyy-MM-dd HH:mm:ss")
$TotalDuration = $EndTime - $StartTime

# Calculate hours, minutes, and seconds
$Hours = [Math]::Floor($TotalDuration.TotalHours)
$Minutes = [Math]::Floor(($TotalDuration.TotalMinutes) % 60)
$Seconds = $TotalDuration.Seconds

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Deployment Timeline" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Start Time:      $StartTimestamp (UTC+2)" -ForegroundColor White
Write-Host "End Time:        $EndTimestamp (UTC+2)" -ForegroundColor White
Write-Host ""
Write-Host "Total Duration:  $($Hours)h $($Minutes)m $($Seconds)s" -ForegroundColor Yellow
Write-Host "                 ($([Math]::Floor($TotalDuration.TotalSeconds)) seconds)" -ForegroundColor Gray
Write-Host ""
Write-Host "Gateway Deployment: $($GatewayMinutes)m $($GatewaySeconds)s (Parallel)" -ForegroundColor Yellow
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Test connectivity from 192.168.1.0/24 to 10.70.1.0/24" -ForegroundColor White
Write-Host "  2. Test connectivity from 192.168.4.0/24 to 10.70.1.0/24" -ForegroundColor White
Write-Host "  3. Test VPN connectivity between sites" -ForegroundColor White
Write-Host "  4. Verify VM connectivity across VNets" -ForegroundColor White
Write-Host "  5. Monitor Azure Firewall metrics via Azure Portal" -ForegroundColor White
Write-Host "  6. View VM boot diagnostics in Azure Portal" -ForegroundColor White
Write-Host "     • Navigate to VM → Boot diagnostics → Screenshot/Serial log" -ForegroundColor Gray
Write-Host "  7. Monitor VM performance and health" -ForegroundColor White
Write-Host "  8. Verify UDR BGP propagation settings (should be 'No')" -ForegroundColor White
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "VM Boot Diagnostics Access:" -ForegroundColor Yellow
Write-Host "  • Azure Portal → Virtual Machines → [VM Name] → Boot diagnostics" -ForegroundColor White
Write-Host "  • View screenshot of VM console" -ForegroundColor White
Write-Host "  • Download serial log for troubleshooting" -ForegroundColor White
Write-Host "  • Storage Account: $BootDiagStorageAccountName" -ForegroundColor White
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""