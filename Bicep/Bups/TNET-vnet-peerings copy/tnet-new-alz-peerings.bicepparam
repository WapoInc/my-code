using 'tnet-new-alz-peerings.bicep'

param namePrefix = 'tnet-new-alz-peerings'

// Hub VNet — ALZ connectivity hub (sub-connectivity-tnalz01).
param hubSubscriptionId = 'b628c9d5-8a2c-4e24-ba7f-6a8921f9179a'
param hubResourceGroup = 'rg-vnet-hub-prod-southafricanorth'
param hubVnetName = 'vnet-hub-tnalz01-prod-southafricanorth'

// Gateway transit: hub advertises its gateway; each spoke uses the hub remote gateway.
param hubHasGateway = true

// Subscription IDs resolved from names (tn-*): dev-tier subs host both dev and qa VNets.
param spokes = [
  {
    subscriptionId: '0bd0c659-596a-43cc-81e0-5309d3b12187'
    resourceGroup: 'rg-tnalz01-tfr-sap-dev-1'
    vnetName: 'vnet-tnalz01-tfr-sap-dev-1'
  }
  {
    subscriptionId: '0bd0c659-596a-43cc-81e0-5309d3b12187'
    resourceGroup: 'rg-tnalz01-tfr-sap-qa-1'
    vnetName: 'vnet-tnalz01-tfr-sap-qa-1'
  }
  {
    subscriptionId: '1f5f1c1e-05cc-4d57-abc0-78cc8b195b9a'
    resourceGroup: 'rg-tnalz01-tfr-sap-prd-1'
    vnetName: 'vnet-tnalz01-tfr-sap-prd-1'
  }
  {
    subscriptionId: 'b4bc1f82-bf2e-4184-9879-ef8100bac6c9'
    resourceGroup: 'rg-tnalz01-te-sap-dev-1'
    vnetName: 'vnet-tnalz01-te-sap-dev-1'
  }
  {
    subscriptionId: 'b4bc1f82-bf2e-4184-9879-ef8100bac6c9'
    resourceGroup: 'rg-tnalz01-te-sap-qa-1'
    vnetName: 'vnet-tnalz01-te-sap-qa-1'
  }
  {
    subscriptionId: '21036a97-bd30-4dff-812f-8d753380839e'
    resourceGroup: 'rg-tnalz01-te-sap-prd-1'
    vnetName: 'vnet-tnalz01-te-sap-prd-1'
  }
  {
    subscriptionId: 'c3bddc48-d23a-457d-84ae-809e687390d3'
    resourceGroup: 'rg-tnalz01-tcc-sap-dev-1'
    vnetName: 'vnet-tnalz01-tcc-sap-dev-1'
  }
  {
    subscriptionId: 'c3bddc48-d23a-457d-84ae-809e687390d3'
    resourceGroup: 'rg-tnalz01-tcc-sap-qa-1'
    vnetName: 'vnet-tnalz01-tcc-sap-qa-1'
  }
  {
    subscriptionId: 'ba454923-1b2f-4d25-987f-43ef49f5f418'
    resourceGroup: 'rg-tnalz01-tcc-sap-prd-1'
    vnetName: 'vnet-tnalz01-tcc-sap-prd-1'
  }
]
