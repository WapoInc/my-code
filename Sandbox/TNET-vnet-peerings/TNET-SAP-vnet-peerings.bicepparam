using 'TNET-SAP-vnet-peerings.bicep'

// Tenant: 5cba78fe-cc40-479a-9ee1-255423641bc9

// Hub VNet (sub-1)
param hubSubscriptionId = '29df7078-c53c-4638-81c1-e4bc8566d423'
param hubResourceGroup = 'hub-tnet-vnet-peering-poc'
param hubVnetName = 'hub-tnet-vnet-peering-poc'

// Spoke 2 VNet (sub-2)
param spoke2SubscriptionId = 'c08097e2-6ca3-4281-a814-3297c6422805'
param spoke2ResourceGroup = 'spoke-1-tnet-vnet-peering-poc'
param spoke2VnetName = 'spoke-1-tnet-vnet-peering-poc'

// Spoke 3 VNet (sub-3)
param spoke3SubscriptionId = 'f3a0d030-20a3-4003-a4f8-9535f74ad2a7'
param spoke3ResourceGroup = 'spoke-2-tnet-vnet-peering-poc'
param spoke3VnetName = 'spoke-2-tnet-vnet-peering-poc'

// Enables gateway transit: hub peerings advertise the gateway; spokes use the hub remote gateway.
param hubHasGateway = true

// Gateway + subnets already exist; skip redeploying them (ER gateways aren't idempotent on re-PUT).
param deployHubGateway = false
