// =====================================================================
// Harbor & Pine / Keystone - Network foundation
// Deploy with:  az deployment sub create --subscription Keystone --location eastus2 --template-file main.bicep
// =====================================================================

// Subscription scope so this file can reach the resource group in each
// subscription. Modules below set their own scope.
targetScope = 'subscription'

@description('Region for everything. Bastion Developer is not offered in East US, so East US 2 is the default.')
param location string = 'eastus2'

@description('HarborPine subscription (hub).')
param hubSubscriptionId string = '487eb5d1-2d0b-4511-9907-2cdf9c0a55a0'

@description('Keystone subscription (spoke).')
param keystoneSubscriptionId string = 'e634b1bc-c065-4d25-b656-edd0bd26a6df'

@description('Existing resource group for Harbor & Pine shared networking (hub).')
param hubRgName string = 'harborpine-prod-rg'

@description('Existing resource group for Keystone production resources.')
param keystoneRgName string = 'keystone-prod-rg'

@description('Private DNS zone for internal name resolution. Avoid .local - it conflicts with mDNS.')
param privateDnsZoneName string = 'harborpine.internal'

@description('Existing Key Vault (created in the portal) holding the VM admin password.')
param keyVaultName string = 'kv-keystone-lab'

@description('Name of the secret in that vault.')
param webAdminPasswordSecretName string = 'vm-web-admin-password'

@description('Local admin username for the web VMs. "admin" and "administrator" are rejected by Azure.')
param webAdminUsername string = 'keystoneadmin'

@description('Web-tier VMs: name + availability zone. Two zones = survives a datacenter outage.')
param webVms array = [
  {
    name: 'vm-web-01'
    zone: '1'
  }
  {
    name: 'vm-web-02'
    zone: '2'
  }
]

// ---- Storage --------------------------------------------------------
@description('Claims (system of record) storage account. Globally unique, 3-24 lowercase alphanumerics.')
param claimsStorageName string = 'stclaims${take(uniqueString(keystoneSubscriptionId, keystoneRgName), 10)}'

@description('Web farm Azure Files storage account. Globally unique, 3-24 lowercase alphanumerics.')
param webfarmStorageName string = 'stwebfarm${take(uniqueString(keystoneSubscriptionId, keystoneRgName), 10)}'

@description('AUDIT WINDOW ONLY: auditor IP + your IP. Redeploy with [] after 48 hours to close it.')
param claimsTemporaryAllowedIps array = []

@description('Your Entra object ID - gets Storage Blob Data Contributor on the claims account (shared key is off). az ad signed-in-user show --query id -o tsv')
param claimsDataContributorPrincipalId string = ''

param hubCostCenter string = '101'
param keystoneCostCenter string = '201'

// Tags are required by the tagging policy - every resource gets one of these.
var hubTags = {
  Department: 'IT'
  CostCenter: hubCostCenter
}
var keystoneTags = {
  Department: 'Claims'
  CostCenter: keystoneCostCenter
}

// ---------------------------------------------------------------------
// Resource groups (already created, one per subscription)
// ---------------------------------------------------------------------
resource hubRg 'Microsoft.Resources/resourceGroups@2024-03-01' existing = {
  name: hubRgName
  scope: subscription(hubSubscriptionId)
}

resource keystoneRg 'Microsoft.Resources/resourceGroups@2024-03-01' existing = {
  name: keystoneRgName
  scope: subscription(keystoneSubscriptionId)
}

// ---------------------------------------------------------------------
// Virtual networks
// ---------------------------------------------------------------------
module hubNetwork 'modules/hub-network.bicep' = {
  name: 'hub-network'
  scope: hubRg
  params: {
    location: location
    tags: hubTags
  }
}

module keystoneNetwork 'modules/keystone-network.bicep' = {
  name: 'keystone-network'
  scope: keystoneRg
  params: {
    location: location
    tags: keystoneTags
  }
}

// ---------------------------------------------------------------------
// Peering - one per direction. A peering is a child of the LOCAL VNet,
// so each one deploys into that VNet's resource group.
// ---------------------------------------------------------------------
module hubToKeystone 'modules/peering.bicep' = {
  name: 'peer-hub-to-keystone'
  scope: hubRg
  params: {
    localVnetName: hubNetwork.outputs.vnetName
    remoteVnetId: keystoneNetwork.outputs.vnetId
    peeringName: 'peer-hub-to-keystone'
  }
}

module keystoneToHub 'modules/peering.bicep' = {
  name: 'peer-keystone-to-hub'
  scope: keystoneRg
  params: {
    localVnetName: keystoneNetwork.outputs.vnetName
    remoteVnetId: hubNetwork.outputs.vnetId
    peeringName: 'peer-keystone-to-hub'
  }
}

// ---------------------------------------------------------------------
// Private DNS - one zone (in the hub subscription) linked to both VNets.
// Peering alone does NOT share DNS; each VNet must be linked to the zone.
// Linking a VNet from another subscription works as long as both are in
// the same Entra tenant and you have rights on both.
// ---------------------------------------------------------------------
module privateDns 'modules/private-dns.bicep' = {
  name: 'private-dns'
  scope: hubRg
  params: {
    zoneName: privateDnsZoneName
    tags: hubTags
    vnetLinks: [
      {
        name: 'link-hp-hub'
        vnetId: hubNetwork.outputs.vnetId
        registration: true
      }
      {
        name: 'link-keystone'
        vnetId: keystoneNetwork.outputs.vnetId
        registration: true
      }
    ]
  }
}

// ---------------------------------------------------------------------
// Bastion (Developer SKU) - must live in the Keystone VNet, because
// Developer SKU does not work across peering.
// ---------------------------------------------------------------------
module bastion 'modules/bastion.bicep' = {
  name: 'bastion'
  scope: keystoneRg
  params: {
    location: location
    tags: keystoneTags
    vnetId: keystoneNetwork.outputs.vnetId
  }
}

// ---------------------------------------------------------------------
// Web-tier VMs. The admin password is read from Key Vault at deploy time.
// getSecret() only works when passed straight into a module's @secure()
// param - the value never appears in deployment history or outputs.
// Requires the vault's "Azure Resource Manager for template deployment" setting.
// ---------------------------------------------------------------------
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
  scope: resourceGroup(keystoneSubscriptionId, keystoneRgName)
}

// ---------------------------------------------------------------------
// Public Standard Load Balancer in front of the web VMs (+ outbound rules)
// ---------------------------------------------------------------------
module webLb 'modules/load-balancer.bicep' = {
  name: 'web-lb'
  scope: keystoneRg
  params: {
    location: location
    tags: keystoneTags
    dnsLabel: 'keystone-claims-${take(uniqueString(keystoneSubscriptionId, keystoneRgName), 6)}'
    loadDistribution: 'Default' // 'SourceIP' if the legacy app keeps sessions in memory
  }
}

module webVm 'modules/web-vm.bicep' = [for vm in webVms: {
  name: 'web-vm-${vm.name}'
  scope: keystoneRg
  params: {
    location: location
    tags: keystoneTags
    vmName: vm.name
    zone: vm.zone
    subnetId: keystoneNetwork.outputs.webSubnetId
    adminUsername: webAdminUsername
    adminPassword: keyVault.getSecret(webAdminPasswordSecretName)
    loadBalancerBackendPoolIds: [
      webLb.outputs.backendPoolId
    ]
  }
}]

// ---------------------------------------------------------------------
// Private Link DNS zones. Names must be EXACTLY these - Azure's public DNS
// CNAMEs <account>.blob.core.windows.net to <account>.privatelink.blob...,
// and these zones answer that name with the private endpoint's IP for
// any linked VNet. No auto-registration: the PE zone groups write records.
// ---------------------------------------------------------------------
var privateLinkZones = [
  'privatelink.blob.${environment().suffixes.storage}'
  'privatelink.file.${environment().suffixes.storage}'
]

module privateLinkDns 'modules/private-dns.bicep' = [for zone in privateLinkZones: {
  name: 'dns-${replace(zone, '.', '-')}'
  scope: hubRg
  params: {
    zoneName: zone
    tags: hubTags
    vnetLinks: [
      {
        name: 'link-hp-hub'
        vnetId: hubNetwork.outputs.vnetId
        registration: false
      }
      {
        name: 'link-keystone'
        vnetId: keystoneNetwork.outputs.vnetId
        registration: false
      }
    ]
  }
}]

// ---------------------------------------------------------------------
// Claims storage (blob) - system of record
// ---------------------------------------------------------------------
module claimsStorage 'modules/claims-storage.bicep' = {
  name: 'claims-storage'
  scope: keystoneRg
  params: {
    location: location
    tags: keystoneTags
    storageAccountName: claimsStorageName
    subnetId: keystoneNetwork.outputs.dataSubnetId
    blobPrivateDnsZoneId: privateLinkDns[0].outputs.zoneId
    temporaryAllowedIps: claimsTemporaryAllowedIps
    dataContributorPrincipalId: claimsDataContributorPrincipalId
  }
}

// ---------------------------------------------------------------------
// Web farm file share (Azure Files) - shared working storage for the web VMs
// ---------------------------------------------------------------------
module webfarmFiles 'modules/webfarm-files.bicep' = {
  name: 'webfarm-files'
  scope: keystoneRg
  params: {
    location: location
    tags: keystoneTags
    storageAccountName: webfarmStorageName
    subnetId: keystoneNetwork.outputs.dataSubnetId
    filePrivateDnsZoneId: privateLinkDns[1].outputs.zoneId
    keyVaultName: keyVaultName
  }
}

// Outputs the VM/LB templates will need later
output keystoneVnetId string = keystoneNetwork.outputs.vnetId
output keystoneWebSubnetId string = keystoneNetwork.outputs.webSubnetId
output keystoneDataSubnetId string = keystoneNetwork.outputs.dataSubnetId
output hubVnetId string = hubNetwork.outputs.vnetId
output privateDnsZoneName string = privateDns.outputs.zoneName
output webVmNicIds array = [for (vm, i) in webVms: webVm[i].outputs.nicId]
output webVmPrivateIps array = [for (vm, i) in webVms: webVm[i].outputs.privateIp]
output webLbPublicIp string = webLb.outputs.publicIp
output webLbFqdn string = webLb.outputs.fqdn
output claimsStorageAccount string = claimsStorage.outputs.storageAccountName
output webfarmStorageAccount string = webfarmFiles.outputs.storageAccountName
output webfarmUncPath string = webfarmFiles.outputs.uncPath
