
Connect-AzAccount
Get-AzSubscription
Select-AzSubscription -SubscriptionName "@viresent - AIRS"


#How to get BGP Neighbour Address of a VNET GW
https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-bgp-overview#what-address-does-azure-vpn-gateway-use-for-bgp-peer-ip
What address does Azure VPN gateway use for BGP Peer IP?
The Azure VPN gateway will allocate a single IP address from the GatewaySubnet range for active-standby VPN gateways, 
or two IP addresses for active-active VPN gateways. You can get the actual BGP IP address(es) 
allocated by using PowerShell (Get-AzVirtualNetworkGateway, 
look for the “bgpPeeringAddress” property), or in the Azure portal 
(under the “Configure BGP ASN” property on the Gateway Configuration page).


Get-AzVirtualNetworkGateway


