param publicip string
param loc string
resource mypublicip 'Microsoft.Network/publicIPAddresses@2021-05-01' {
  name: publicip
  location: loc
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
  }
}
