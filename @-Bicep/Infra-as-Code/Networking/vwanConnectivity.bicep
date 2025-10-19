// https://github.com/Azure/ALZ-Bicep/tree/main/infra-as-code/bicep/modules/vwanConnectivity


metadata name = 'ALZ Bicep - Azure vWAN Connectivity Module'
metadata description = 'Module used to set up vWAN Connectivity'

@sys.description('Region in which the resource group was created.')
param parLocation string = resourceGroup().location

@sys.description('Prefix value which will be prepended to all resource names.')
param parCompanyPrefix string = 'alz'

@sys.description('The IP address range in CIDR notation for the vWAN virtual Hub to use.')
param parVirtualHubAddressPrefix string = '10.100.0.0/23'

@sys.description('Switch to enable/disable Virtual Hub deployment.')
param parVirtualHubEnabled bool = true

@sys.description('Switch to enable/disable VPN Gateway deployment.')
param parVpnGatewayEnabled bool = true

@sys.description('Switch to enable/disable ExpressRoute Gateway deployment.')
param parExpressRouteGatewayEnabled bool = true

@sys.description('Prefix Used for Virtual WAN.')
param parVirtualWanName string = '${parCompanyPrefix}-vwan-${parLocation}'

@sys.description('Prefix Used for Virtual WAN Hub.')
param parVirtualWanHubName string = '${parCompanyPrefix}-vhub-${parLocation}'

@sys.description('Prefix Used for VPN Gateway.')
param parVpnGatewayName string = '${parCompanyPrefix}-vpngw-${parLocation}'

@sys.description('Prefix Used for ExpressRoute Gateway.')
param parExpressRouteGatewayName string = '${parCompanyPrefix}-ergw-${parLocation}'

@sys.description('The scale unit for this VPN Gateway.')
param parVpnGatewayScaleUnit int = 1

@sys.description('The scale unit for this ExpressRoute Gateway.')
param parExpressRouteGatewayScaleUnit int = 1

@sys.description('Tags you would like to be applied to all resources in this module.')
param parTags object = {}

@sys.description('Set Parameter to true to Opt-out of deployment telemetry')
param parTelemetryOptOut bool = false

// Virtual WAN resource
resource resVwan 'Microsoft.Network/virtualWans@2021-08-01' = {
  name: parVirtualWanName
  location: parLocation
  tags: parTags
  properties: {
    allowBranchToBranchTraffic: true
    allowVnetToVnetTraffic: true
    disableVpnEncryption: false
    type: 'Standard'
  }
}

// Virtual WAN Hub
resource resVhub 'Microsoft.Network/virtualHubs@2021-08-01' = if (parVirtualHubEnabled && !empty(parVirtualHubAddressPrefix)) {
  name: parVirtualWanHubName
  location: parLocation
  tags: parTags
  properties: {
    addressPrefix: parVirtualHubAddressPrefix
    sku: 'Standard'
    virtualWan: {
      id: resVwan.id
    }
  }
}

// Virtual VPN-GW resource
resource resVpnGateway 'Microsoft.Network/vpnGateways@2021-05-01' = if (parVirtualHubEnabled && parVpnGatewayEnabled) {
  name: parVpnGatewayName
  location: parLocation
  tags: parTags
  properties: {
    bgpSettings: {
      asn: 65515
      bgpPeeringAddress: ''
      peerWeight: 5
    }
    virtualHub: {
      id: resVhub.id
    }
    vpnGatewayScaleUnit: parVpnGatewayScaleUnit
  }
}

// Virtual ER-GW resource
resource resErGateway 'Microsoft.Network/expressRouteGateways@2021-05-01' = if (parVirtualHubEnabled && parExpressRouteGatewayEnabled) {
  name: parExpressRouteGatewayName
  location: parLocation
  tags: parTags
  properties: {
    virtualHub: {
      id: resVhub.id
    }
    autoScaleConfiguration: {
      bounds: {
        min: parExpressRouteGatewayScaleUnit
      }
    }
  }
}


// Output Virtual WAN name and ID
output outVirtualWanName string = resVwan.name
output outVirtualWanId string = resVwan.id

// Output Virtual WAN Hub name and ID
output outVirtualHubName string = resVhub.name
output outVirtualHubId string = resVhub.id
