// Keystone spoke VNet: 10.0.2.0/24 split into /26s
//   10.0.2.0/26    snet-web    (web tier - claims app VMs behind the LB)
//   10.0.2.64/26   snet-data   (database / file tier)
//   10.0.2.128/26  reserved for growth (not created)
//   10.0.2.192/26  reserved for growth (not created)
param location string
param tags object

param vnetName string = 'vnet-keystone'
param addressSpace string = '10.0.2.0/24'
param webSubnetPrefix string = '10.0.2.0/26'
param dataSubnetPrefix string = '10.0.2.64/26'

// ---------------------------------------------------------------------
// Web tier NSG - the only tier that accepts Internet traffic, and only on 80/443.
// The VMs have no public IPs; this traffic arrives through the public load balancer.
// A Standard LB is "secure by default", so without this rule nothing gets in.
// ---------------------------------------------------------------------
resource webNsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: 'nsg-keystone-web'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-HTTP-HTTPS-From-Internet'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRanges: [
            '80'
            '443'
          ]
        }
      }
    ]
  }
}

// ---------------------------------------------------------------------
// Data tier NSG - accepts traffic from the web subnet ONLY.
// The explicit deny at 4096 matters: Azure's default rule 65000
// (AllowVnetInBound) would otherwise let the hub and every other
// subnet in. Custom rules always win over default rules.
// ---------------------------------------------------------------------
resource dataNsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: 'nsg-keystone-data'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        // Renaming a rule = delete + recreate, which is fine on a redeploy.
        name: 'Allow-HTTPS-SMB-SQL-From-Web'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: webSubnetPrefix
          sourcePortRange: '*'
          destinationAddressPrefix: dataSubnetPrefix
          destinationPortRanges: [
            '443'  // Blob private endpoint (HTTPS)
            '445'  // SMB - Azure Files private endpoint / file servers
            '1433' // SQL Server
          ]
        }
      }
      {
        name: 'Deny-All-Other-Inbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
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
    subnets: [
      {
        name: 'snet-web'
        properties: {
          addressPrefix: webSubnetPrefix
          networkSecurityGroup: {
            id: webNsg.id
          }
        }
      }
      {
        name: 'snet-data'
        properties: {
          addressPrefix: dataSubnetPrefix
          networkSecurityGroup: {
            id: dataNsg.id
          }
          // Private endpoints live in this subnet. By default NSG rules are
          // IGNORED for private endpoint traffic - this makes the NSG apply,
          // so the deny-all above really does protect the storage endpoints.
          privateEndpointNetworkPolicies: 'NetworkSecurityGroupEnabled'
        }
      }
    ]
  }
}

output vnetName string = vnet.name
output vnetId string = vnet.id
output webSubnetId string = vnet.properties.subnets[0].id
output dataSubnetId string = vnet.properties.subnets[1].id
