// One Keystone web-tier VM: Windows Server + IIS, private IP only.
// Deployed once per VM from main.bicep (each in its own availability zone).
param location string
param tags object
param vmName string
param subnetId string

@description('Availability zone for this VM. Spreading VMs across zones survives a datacenter failure.')
param zone string

param adminUsername string

@secure()
@description('Comes from Key Vault via getSecret() in main.bicep - never stored in this repo.')
param adminPassword string

@description('Load balancer backend pool(s) this NIC joins. Empty = not load balanced.')
param loadBalancerBackendPoolIds array = []

@description('B2s = 2 vCPU / 4 GB. B1s (1 GB) is too small for Windows Server.')
param vmSize string = 'Standard_B2s'

// ---------------------------------------------------------------------
// NIC - no publicIPAddress block at all. That is the "no public IP" requirement.
// ---------------------------------------------------------------------
resource nic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: 'nic-${vmName}'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnetId
          }
          // NIC-based backend pool membership. Adding this to an existing
          // NIC is an in-place update - the VM is not recreated.
          loadBalancerBackendAddressPools: [for poolId in loadBalancerBackendPoolIds: {
            id: poolId
          }]
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: vmName
  location: location
  tags: tags
  zones: [
    zone
  ]
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      // computerName becomes the hostname, which private DNS auto-registers
      // as <computerName>.harborpine.internal. Windows limit: 15 characters.
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter-smalldisk-g2' // 30 GB OS disk - cheaper than the 127 GB default
        version: 'latest'
      }
      osDisk: {
        name: 'osdisk-${vmName}'
        createOption: 'FromImage'
        deleteOption: 'Delete' // disk is removed with the VM - no orphaned disks billing you
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
    }
    securityProfile: {
      securityType: 'TrustedLaunch'
      uefiSettings: {
        secureBootEnabled: true
        vTpmEnabled: true
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true // managed storage; lets you see the boot screenshot / serial log in the portal
      }
    }
  }
}

// ---------------------------------------------------------------------
// Install IIS and write a page that shows WHICH server answered.
// When the load balancer is in place, refreshing the page proves traffic
// is being spread across both VMs (and that failover works).
// Install-WindowsFeature uses local media, so no internet access is needed.
// ---------------------------------------------------------------------
resource iis 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = {
  parent: vm
  name: 'install-iis'
  location: location
  tags: tags
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      commandToExecute: 'powershell -ExecutionPolicy Bypass -Command "Install-WindowsFeature -Name Web-Server -IncludeManagementTools; Set-Content -Path C:\\inetpub\\wwwroot\\iisstart.htm -Value (\'<h1>Keystone Claims</h1><p>Served by: \' + $env:COMPUTERNAME + \'</p>\')"'
    }
  }
}

output vmName string = vm.name
output nicId string = nic.id
output privateIp string = nic.properties.ipConfigurations[0].properties.privateIPAddress
