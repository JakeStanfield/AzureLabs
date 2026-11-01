// Harbor & Pine hub VNet: 10.0.1.0/24
param location string
param tags object

param vnetName string = 'vnet-hp-hub'
param addressSpace string = '10.0.1.0/24'
param sharedSubnetPrefix string = '10.0.1.0/26'

resource sharedNsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: 'nsg-hp-shared'
  location: location
  tags: tags
  properties: {
    // No custom rules yet - Azure's default rules apply:
    //   allow VNet-to-VNet (includes peered VNets), allow LB probes, deny Internet inbound.
    securityRules: []
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressSpace
      ]
    }
    // Subnets are defined INLINE so redeploying the VNet never tries to remove them.
    subnets: [
      {
        name: 'snet-shared'
        properties: {
          addressPrefix: sharedSubnetPrefix
          networkSecurityGroup: {
            id: sharedNsg.id
          }
        }
      }
    ]
  }
}

output vnetName string = vnet.name
output vnetId string = vnet.id
