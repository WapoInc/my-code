# Use native RDP client to connect to VM over Bastion

Connect-AzAccount
Get-AzSubscription

Select-AzSubscription -SubscriptionName "@viresent - AIRS"
Select-AzSubscription -SubscriptionName "Dele - Microsoft Azure Internal Consumption"

#------------------------------------------------------------------------------------------------------------------------------------


$BastionName   = "ZA-East-vDC-vnet-bastion"
$ResourceGroup = "ZA-East-vDC"
$VMResourceID = "/subscriptions/d062d828-c0dd-4884-8ac1-9db448832345/resourceGroups/ZA-East-vDC/providers/Microsoft.Compute/virtualMachines/JumpBox-ZA-East-vDC"

az network bastion rdp --name $BastionName --resource-group $ResourceGroup --target-resource-id $VMResourceID


#------------------------------------------------------------------------------------------------------------------------------------

#vmr-FG-PoC
$BastionName   = "vmr-FG-PoC-Bastion"
$ResourceGroup = "vmr-FG-PoC"


#FG-VM-1:
$VMResourceID = "/subscriptions/6053e2de-7b5f-4318-b606-661ae10c29ab/resourceGroups/vmr-FG-PoC/providers/Microsoft.Compute/virtualMachines/FG-VM-1"
#FG-VM-2:
$VMResourceID = "/subscriptions/6053e2de-7b5f-4318-b606-661ae10c29ab/resourceGroups/VMR-FG-POC/providers/Microsoft.Compute/virtualMachines/FG-VM-2"

az network bastion rdp --name $BastionName --resource-group $ResourceGroup --target-resource-id $VMResourceID

