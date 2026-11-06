// Private DNS zone shared by Harbor & Pine and Keystone.
// Lives in the hub resource group because DNS is a shared service.
//
// Private DNS zones and their VNet links are GLOBAL resources (location: 'global'),
// not regional. If your allowed-locations policy is custom-written and doesn't
// exempt 'global', it will block this deployment.
param zoneName string
param tags object

@description('VNets to link. registration = true means VMs in that VNet auto-create A records.')
param vnetLinks array // [{ name: string, vnetId: string, registration: bool }]

resource zone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: zoneName
  location: 'global'
  tags: tags
}

resource links 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = [for link in vnetLinks: {
  parent: zone
  name: link.name
  location: 'global'
  tags: tags
  properties: {
    virtualNetwork: {
      id: link.vnetId
    }
    // Auto-registration: when a VM's NIC comes up in this VNet, Azure creates
    // an A record for it (vm-name.zoneName) and removes it when the VM is deleted.
    registrationEnabled: link.registration
  }
}]

output zoneName string = zone.name
output zoneId string = zone.id
