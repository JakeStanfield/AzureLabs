// Azure Bastion - Developer SKU (free).
//   - No AzureBastionSubnet, no public IP: it attaches to the VNet by reference.
//   - Reaches VMs in THIS VNet only (no peering support), one session at a time.
//   - Portal-only connections (no native client, no shareable links).
//   - SKU can be upgraded later; it can never be downgraded.
param location string
param tags object
param vnetId string
param bastionName string = 'bas-keystone-dev'

resource bastion 'Microsoft.Network/bastionHosts@2024-05-01' = {
  name: bastionName
  location: location
  tags: tags
  sku: {
    name: 'Developer'
  }
  properties: {
    virtualNetwork: {
      id: vnetId
    }
  }
}

output bastionId string = bastion.id
