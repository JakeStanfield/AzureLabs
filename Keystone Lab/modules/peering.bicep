// One direction of a VNet peering. Deploy this module twice (A->B and B->A).
// Peering is not transitive and not automatic in reverse - both sides must exist
// before the peering status shows "Connected".
param localVnetName string
param remoteVnetId string
param peeringName string

resource localVnet 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  name: localVnetName
}

resource peering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-11-01' = {
  parent: localVnet
  name: peeringName
  properties: {
    remoteVirtualNetwork: {
      id: remoteVnetId
    }
    allowVirtualNetworkAccess: true // the two VNets can talk
    allowForwardedTraffic: false    // no traffic relayed through an NVA (none in this design)
    allowGatewayTransit: false      // no VPN/ExpressRoute gateway in the hub yet
    useRemoteGateways: false
  }
}
