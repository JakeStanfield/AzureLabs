param routeTables_rt_CoreServices_name string = 'rt-CoreServices'
param virtualMachines_CoreServicesVM_name string = 'CoreServicesVM'
param virtualMachines_ManufacturingVM_name string = 'ManufacturingVM'
param virtualNetworks_ManufacturingVnet_name string = 'ManufacturingVnet'
param networkInterfaces_coreservicesvm810_name string = 'coreservicesvm810'
param virtualNetworks_CoreServicesVM_vnet_name string = 'CoreServicesVM-vnet'
param networkInterfaces_manufacturingvm673_name string = 'manufacturingvm673'
param networkSecurityGroups_CoreServicesVM_nsg_name string = 'CoreServicesVM-nsg'
param networkSecurityGroups_ManufacturingVM_nsg_name string = 'ManufacturingVM-nsg'

resource networkSecurityGroups_CoreServicesVM_nsg_name_resource 'Microsoft.Network/networkSecurityGroups@2025-05-01' = {
  name: networkSecurityGroups_CoreServicesVM_nsg_name
  location: 'eastus'
  properties: {
    securityRules: []
  }
}

resource networkSecurityGroups_ManufacturingVM_nsg_name_resource 'Microsoft.Network/networkSecurityGroups@2025-05-01' = {
  name: networkSecurityGroups_ManufacturingVM_nsg_name
  location: 'eastus'
  properties: {
    securityRules: []
  }
}

resource routeTables_rt_CoreServices_name_resource 'Microsoft.Network/routeTables@2025-05-01' = {
  name: routeTables_rt_CoreServices_name
  location: 'eastus'
  properties: {
    disableBgpRoutePropagation: true
    routes: [
      {
        name: 'PerimetertoCore'
        id: routeTables_rt_CoreServices_name_PerimetertoCore.id
        properties: {
          addressPrefix: '10.0.0.0/16'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: '10.0.1.7'
        }
        type: 'Microsoft.Network/routeTables/routes'
      }
    ]
  }
}

resource virtualMachines_CoreServicesVM_name_resource 'Microsoft.Compute/virtualMachines@2025-04-01' = {
  name: virtualMachines_CoreServicesVM_name
  location: 'eastus'
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v3'
    }
    additionalCapabilities: {
      hibernationEnabled: false
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2025-datacenter-g2'
        version: 'latest'
      }
      osDisk: {
        osType: 'Windows'
        name: '${virtualMachines_CoreServicesVM_name}_disk1_d7ce582d2b084f17af6691739260affb'
        createOption: 'FromImage'
        caching: 'ReadWrite'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
          id: resourceId(
            'Microsoft.Compute/disks',
            '${virtualMachines_CoreServicesVM_name}_disk1_d7ce582d2b084f17af6691739260affb'
          )
        }
        deleteOption: 'Delete'
        diskSizeGB: 127
      }
      dataDisks: []
      diskControllerType: 'SCSI'
    }
    osProfile: {
      computerName: virtualMachines_CoreServicesVM_name
      adminUsername: 'localadmin'
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: true
        patchSettings: {
          patchMode: 'AutomaticByOS'
          assessmentMode: 'ImageDefault'
          enableHotpatching: false
        }
      }
      secrets: []
      allowExtensionOperations: true
      requireGuestProvisionSignal: true
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterfaces_coreservicesvm810_name_resource.id
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}

resource virtualMachines_ManufacturingVM_name_resource 'Microsoft.Compute/virtualMachines@2025-04-01' = {
  name: virtualMachines_ManufacturingVM_name
  location: 'eastus'
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v3'
    }
    additionalCapabilities: {
      hibernationEnabled: false
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2025-datacenter-g2'
        version: 'latest'
      }
      osDisk: {
        osType: 'Windows'
        name: '${virtualMachines_ManufacturingVM_name}_disk1_bcb60f1d87d547e28e7d37f0c2036662'
        createOption: 'FromImage'
        caching: 'ReadWrite'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
          id: resourceId(
            'Microsoft.Compute/disks',
            '${virtualMachines_ManufacturingVM_name}_disk1_bcb60f1d87d547e28e7d37f0c2036662'
          )
        }
        deleteOption: 'Delete'
        diskSizeGB: 127
      }
      dataDisks: []
      diskControllerType: 'SCSI'
    }
    osProfile: {
      computerName: virtualMachines_ManufacturingVM_name
      adminUsername: 'localadmin'
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: true
        patchSettings: {
          patchMode: 'AutomaticByOS'
          assessmentMode: 'ImageDefault'
          enableHotpatching: false
        }
      }
      secrets: []
      allowExtensionOperations: true
      requireGuestProvisionSignal: true
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterfaces_manufacturingvm673_name_resource.id
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
  }
}

resource routeTables_rt_CoreServices_name_PerimetertoCore 'Microsoft.Network/routeTables/routes@2025-05-01' = {
  name: '${routeTables_rt_CoreServices_name}/PerimetertoCore'
  properties: {
    addressPrefix: '10.0.0.0/16'
    nextHopType: 'VirtualAppliance'
    nextHopIpAddress: '10.0.1.7'
  }
  dependsOn: [
    routeTables_rt_CoreServices_name_resource
  ]
}

resource virtualNetworks_ManufacturingVnet_name_resource 'Microsoft.Network/virtualNetworks@2025-05-01' = {
  name: virtualNetworks_ManufacturingVnet_name
  location: 'eastus'
  properties: {
    addressSpace: {
      addressPrefixes: [
        '172.16.0.0/16'
      ]
    }
    privateEndpointVNetPolicies: 'Disabled'
    subnets: [
      {
        name: 'Manufacturing'
        id: virtualNetworks_ManufacturingVnet_name_Manufacturing.id
        properties: {
          addressPrefix: '172.16.0.0/24'
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
        type: 'Microsoft.Network/virtualNetworks/subnets'
      }
    ]
    virtualNetworkPeerings: [
      {
        name: '${virtualNetworks_ManufacturingVnet_name}-to-CoreServicesVnet'
        id: virtualNetworks_ManufacturingVnet_name_virtualNetworks_ManufacturingVnet_name_to_CoreServicesVnet.id
        properties: {
          peeringState: 'Connected'
          peeringSyncLevel: 'FullyInSync'
          remoteVirtualNetwork: {
            id: virtualNetworks_CoreServicesVM_vnet_name_resource.id
          }
          allowVirtualNetworkAccess: true
          allowForwardedTraffic: false
          allowGatewayTransit: false
          useRemoteGateways: false
          doNotVerifyRemoteGateways: false
          peerCompleteVnets: true
          enableOnlyIPv6Peering: false
          remoteAddressSpace: {
            addressPrefixes: [
              '10.0.0.0/16'
            ]
          }
          remoteVirtualNetworkAddressSpace: {
            addressPrefixes: [
              '10.0.0.0/16'
            ]
          }
        }
        type: 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings'
      }
    ]
    enableDdosProtection: false
  }
}

resource virtualNetworks_ManufacturingVnet_name_Manufacturing 'Microsoft.Network/virtualNetworks/subnets@2025-05-01' = {
  name: '${virtualNetworks_ManufacturingVnet_name}/Manufacturing'
  properties: {
    addressPrefix: '172.16.0.0/24'
    delegations: []
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
  dependsOn: [
    virtualNetworks_ManufacturingVnet_name_resource
  ]
}

resource virtualNetworks_CoreServicesVM_vnet_name_perimeter 'Microsoft.Network/virtualNetworks/subnets@2025-05-01' = {
  name: '${virtualNetworks_CoreServicesVM_vnet_name}/perimeter'
  properties: {
    addressPrefix: '10.0.1.0/24'
    delegations: []
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
    defaultOutboundAccess: false
  }
  dependsOn: [
    virtualNetworks_CoreServicesVM_vnet_name_resource
  ]
}

resource networkInterfaces_coreservicesvm810_name_resource 'Microsoft.Network/networkInterfaces@2025-05-01' = {
  name: networkInterfaces_coreservicesvm810_name
  location: 'eastus'
  kind: 'Regular'
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        id: '${networkInterfaces_coreservicesvm810_name_resource.id}/ipConfigurations/ipconfig1'
        type: 'Microsoft.Network/networkInterfaces/ipConfigurations'
        properties: {
          privateIPAddress: '10.0.0.4'
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: virtualNetworks_CoreServicesVM_vnet_name_Core.id
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
    dnsSettings: {
      dnsServers: []
    }
    enableIPForwarding: false
    disableTcpStateTracking: false
    networkSecurityGroup: {
      id: networkSecurityGroups_CoreServicesVM_nsg_name_resource.id
    }
    nicType: 'Standard'
    auxiliaryMode: 'None'
    auxiliarySku: 'None'
  }
}

resource networkInterfaces_manufacturingvm673_name_resource 'Microsoft.Network/networkInterfaces@2025-05-01' = {
  name: networkInterfaces_manufacturingvm673_name
  location: 'eastus'
  kind: 'Regular'
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        id: '${networkInterfaces_manufacturingvm673_name_resource.id}/ipConfigurations/ipconfig1'
        type: 'Microsoft.Network/networkInterfaces/ipConfigurations'
        properties: {
          privateIPAddress: '172.16.0.4'
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: virtualNetworks_ManufacturingVnet_name_Manufacturing.id
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
    dnsSettings: {
      dnsServers: []
    }
    enableAcceleratedNetworking: true
    enableIPForwarding: false
    disableTcpStateTracking: false
    networkSecurityGroup: {
      id: networkSecurityGroups_ManufacturingVM_nsg_name_resource.id
    }
    nicType: 'Standard'
    auxiliaryMode: 'None'
    auxiliarySku: 'None'
  }
}

resource virtualNetworks_CoreServicesVM_vnet_name_resource 'Microsoft.Network/virtualNetworks@2025-05-01' = {
  name: virtualNetworks_CoreServicesVM_vnet_name
  location: 'eastus'
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    privateEndpointVNetPolicies: 'Disabled'
    subnets: [
      {
        name: 'perimeter'
        id: virtualNetworks_CoreServicesVM_vnet_name_perimeter.id
        properties: {
          addressPrefix: '10.0.1.0/24'
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          defaultOutboundAccess: false
        }
        type: 'Microsoft.Network/virtualNetworks/subnets'
      }
      {
        name: 'Core'
        id: virtualNetworks_CoreServicesVM_vnet_name_Core.id
        properties: {
          addressPrefix: '10.0.0.0/24'
          routeTable: {
            id: routeTables_rt_CoreServices_name_resource.id
          }
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
        type: 'Microsoft.Network/virtualNetworks/subnets'
      }
    ]
    virtualNetworkPeerings: [
      {
        name: 'CoreServicesVnet-to-ManufacturingVnet'
        id: virtualNetworks_CoreServicesVM_vnet_name_CoreServicesVnet_to_ManufacturingVnet.id
        properties: {
          peeringState: 'Connected'
          peeringSyncLevel: 'FullyInSync'
          remoteVirtualNetwork: {
            id: virtualNetworks_ManufacturingVnet_name_resource.id
          }
          allowVirtualNetworkAccess: true
          allowForwardedTraffic: true
          allowGatewayTransit: false
          useRemoteGateways: false
          doNotVerifyRemoteGateways: false
          peerCompleteVnets: true
          enableOnlyIPv6Peering: false
          remoteAddressSpace: {
            addressPrefixes: [
              '172.16.0.0/16'
            ]
          }
          remoteVirtualNetworkAddressSpace: {
            addressPrefixes: [
              '172.16.0.0/16'
            ]
          }
        }
        type: 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings'
      }
    ]
    enableDdosProtection: false
  }
}

resource virtualNetworks_CoreServicesVM_vnet_name_Core 'Microsoft.Network/virtualNetworks/subnets@2025-05-01' = {
  name: '${virtualNetworks_CoreServicesVM_vnet_name}/Core'
  properties: {
    addressPrefix: '10.0.0.0/24'
    routeTable: {
      id: routeTables_rt_CoreServices_name_resource.id
    }
    delegations: []
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
  dependsOn: [
    virtualNetworks_CoreServicesVM_vnet_name_resource
  ]
}

resource virtualNetworks_CoreServicesVM_vnet_name_CoreServicesVnet_to_ManufacturingVnet 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2025-05-01' = {
  name: '${virtualNetworks_CoreServicesVM_vnet_name}/CoreServicesVnet-to-ManufacturingVnet'
  properties: {
    peeringState: 'Connected'
    peeringSyncLevel: 'FullyInSync'
    remoteVirtualNetwork: {
      id: virtualNetworks_ManufacturingVnet_name_resource.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
    doNotVerifyRemoteGateways: false
    peerCompleteVnets: true
    enableOnlyIPv6Peering: false
    remoteAddressSpace: {
      addressPrefixes: [
        '172.16.0.0/16'
      ]
    }
    remoteVirtualNetworkAddressSpace: {
      addressPrefixes: [
        '172.16.0.0/16'
      ]
    }
  }
  dependsOn: [
    virtualNetworks_CoreServicesVM_vnet_name_resource
  ]
}

resource virtualNetworks_ManufacturingVnet_name_virtualNetworks_ManufacturingVnet_name_to_CoreServicesVnet 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2025-05-01' = {
  name: '${virtualNetworks_ManufacturingVnet_name}/${virtualNetworks_ManufacturingVnet_name}-to-CoreServicesVnet'
  properties: {
    peeringState: 'Connected'
    peeringSyncLevel: 'FullyInSync'
    remoteVirtualNetwork: {
      id: virtualNetworks_CoreServicesVM_vnet_name_resource.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: false
    allowGatewayTransit: false
    useRemoteGateways: false
    doNotVerifyRemoteGateways: false
    peerCompleteVnets: true
    enableOnlyIPv6Peering: false
    remoteAddressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    remoteVirtualNetworkAddressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
  }
  dependsOn: [
    virtualNetworks_ManufacturingVnet_name_resource
  ]
}
