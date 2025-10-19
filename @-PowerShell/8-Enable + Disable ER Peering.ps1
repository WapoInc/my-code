## Reset a peering ##
# Login to Az
Connect-AzAccount
# If you have multiple Azure subscriptions, check the subscriptions for the account.
Get-AzSubscription
# Specify the subscription that you want to use.
Select-AzSubscription -SubscriptionName "Replace_with_your_subscription_name"
##================================================================================================
# Run the following commands to retrieve your ExpressRoute circuit.
Get-AzExpressRouteCircuit -ResourceGroupName "ER-LTSA-RG"

##================================================================================================
$ckt = Get-AzExpressRouteCircuit -Name "ER-LTSA-2" -ResourceGroupName "ER-LTSA-RG"
#$ckt = Get-AzExpressRouteCircuit -Name "ExpressRouteARMCircuit" -ResourceGroupName "ExpressRouteResourceGroup"

Identify the peering you want to disable or enable. Peerings is an array. In the following example, Peerings[0] is Azure Private Peering and Peerings[1] Microsoft Peering.

##================================================================================================
# To see the output , Type $ckt and hit ENTER

PS C:\Users\viresent> $ckt


Name                             : ER-LTSA-2
ResourceGroupName                : ER-LTSA-RG
Location                         : southafricanorth
Id                               : /subscriptions/d062d828-c0dd-4884-8ac1-9db448832345/resourceGroups/ER-LTSA-RG/providers/Microsoft.Network/expressRouteCircuits/
                                   ER-LTSA-2
Etag                             : W/"b286a6dc-a237-42b7-ac72-2378d2a2ae63"
ProvisioningState                : Succeeded
Sku                              : {
                                     "Name": "Standard_MeteredData",
                                     "Tier": "Standard",
                                     "Family": "MeteredData"
                                   }
CircuitProvisioningState         : Enabled
ServiceProviderProvisioningState : Provisioned
                                       "PeeringType": "AzurePrivatePeering",
ServiceProviderNotes             : 
ServiceProviderProperties        : {
                                     "ServiceProviderName": "Liquid Telecom",
                                     "PeeringLocation": "Johannesburg",
                                     "BandwidthInMbps": 50
                                   }
ExpressRoutePort                 : null
BandwidthInGbps                  : 
Stag                             : 10
ServiceKey                       : f1b47a15-0c13-4d48-820c-cf2bd772d815
Peerings                         : [
                                     {
                                       "Name": "AzurePrivatePeering",
                                       "Etag": "W/\"b286a6dc-a237-42b7-ac72-2378d2a2ae63\"",
                                       "Id": "/subscriptions/d062d828-c0dd-4884-8ac1-9db448832345/resourceGroups/ER-LTSA-RG/providers/Microsoft.Network/expressRou
                                   teCircuits/ER-LTSA-2/peerings/AzurePrivatePeering",
                                       "State": "Enabled",
                                       "AzureASN": 12076,
                                       "PeerASN": 65500,
                                       "PrimaryPeerAddressPrefix": "172.30.0.4/30",
                                       "SecondaryPeerAddressPrefix": "172.30.0.0/30",
                                       "PrimaryAzurePort": "",
                                       "SecondaryAzurePort": "",
                                       "VlanId": 100,
                                       "ProvisioningState": "Succeeded",
                                       "GatewayManagerEtag": "8",
                                       "LastModifiedBy": "Customer",
                                       "Connections": [],
                                       "PeeredConnections": []
                                     }
                                   ]
Authorizations                   : []
AllowClassicOperations           : False
GatewayManagerEtag               : 8

##================================================================================================

Run the following commands to change the state of the peering.

## Disable ER Private Peering Circuit
$ckt.Peerings[0].State = "Disabled"

## Enable ER Private Peering Circuit
$ckt.Peerings[0].State = "Enabled"
Set-AzExpressRouteCircuit -ExpressRouteCircuit $ckt


The peering should be in a state you set.