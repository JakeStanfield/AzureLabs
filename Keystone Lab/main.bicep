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

// Outputs the VM/LB templates will need later
output keystoneVnetId string = keystoneNetwork.outputs.vnetId
output keystoneWebSubnetId string = keystoneNetwork.outputs.webSubnetId
output keystoneDataSubnetId string = keystoneNetwork.outputs.dataSubnetId
output hubVnetId string = hubNetwork.outputs.vnetId
