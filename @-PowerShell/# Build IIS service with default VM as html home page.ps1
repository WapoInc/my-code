# Build IIS service with default VM as html home page

# Login to Azure
Connect-AzAccount
Get-AzSubscription
Select-AzSubscription -SubscriptionName "@viresent - AIRS"


# Build IIS service with default VM as html home page
Set-AzVMExtension -ResourceGroupName AFD-CDN-PoC -ExtensionName IIS -VMName VM01 -Publisher Microsoft.Compute -ExtensionType CustomScriptExtension -TypeHandlerVersion 1.4 -SettingString '{"commandToExecute":"powershell Add-WindowsFeature Web-Server; powershell Add-Content -Path \"C:\\inetpub\\wwwroot\\Default.htm\" -Value $($env:computername)"}' -Location "SouthAfricaNorth" 