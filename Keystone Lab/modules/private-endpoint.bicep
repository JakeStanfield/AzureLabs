// A private endpoint for ONE sub-resource (blob, file, ...) of one resource.
// Azure creates a NIC with a private IP in the subnet. The DNS zone group
// writes and maintains the A record in the matching privatelink.* zone,
// so <account>.blob.core.windows.net resolves to that private IP from
// any VNet linked to the zone.
param location string
param tags object
param name string
param subnetId string

@description('Resource ID of the target (e.g. the storage account).')
param targetResourceId string

@description('Sub-resource: blob, file, dfs, queue, table, web...')
param groupId string

@description('Resource ID of the privatelink.<groupId>.core.windows.net zone.')
param privateDnsZoneId string

resource pe 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    subnet: {
      id: subnetId
    }
    customNetworkInterfaceName: 'nic-${name}'
    privateLinkServiceConnections: [
      {
        name: name
        properties: {
          privateLinkServiceId: targetResourceId
          groupIds: [
            groupId
          ]
        }
      }
    ]
  }
}

resource zoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = {
  parent: pe
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: replace(groupId, '.', '-')
        properties: {
          privateDnsZoneId: privateDnsZoneId
        }
      }
    ]
  }
}

output privateEndpointId string = pe.id
