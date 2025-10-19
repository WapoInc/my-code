# Connect cross-tenant virtual networks to a Virtual WAN hub


# Login to Azure
Connect-AzAccount -Tenant MngEnv461963.onmicrosoft.com
Connect-AzAccount -Tenant 6fe43f5b-2756-4cb3-a808-b8a71f2af1dc




Get-AzSubscription

# Select-AzSubscription -SubscriptionName "Enter your Sub name"
Select-AzSubscription -SubscriptionName "@viresent - New AIRS-ME-MngEnv461963" -Tenant MngEnv461963.onmicrosoft.com

Connect-AzAccount -Tenant 6fe43f5b-2756-4cb3-a808-b8a71f2af1dc
Select-AzSubscription -SubscriptionName "@Vince_Resente@Hotmail - Visual Studio Enterprise Subscription" -Tenant 6fe43f5b-2756-4cb3-a808-b8a71f2af1dc




#Enter your variables
$




# Connect a virtual network to a hub
Select-AzSubscription -SubscriptionId "4abd2eb6-69f3-4c57-9590-bd22917bfe45"


# Create a local variable to store the metadata of the virtual network that you want to connect to the hub:
$remote = Get-AzVirtualNetwork -Name "Spoke-VNET-in-VS" -ResourceGroupName "ER-Circuit-Auth-PoC"



# Switch back to the parent account:
Connect-AzAccount -Tenant MngEnv461963.onmicrosoft.com
Select-AzSubscription -SubscriptionName "@viresent - New AIRS-ME-MngEnv461963" -Tenant MngEnv461963.onmicrosoft.com




# Connect the virtual network to the hub:

New-AzVirtualHubVnetConnection -ResourceGroupName "AVS-ZA-North" -VirtualHubName "AVS-vWAN-Transit-Hub" -Name "VNET-Connection-to-VS-VNET" -RemoteVirtualNetwork $remote
