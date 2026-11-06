// =====================================================================
// Claims document storage - the system of record for scanned claim files.
//   Durability : Standard_GRS (archive tier would need LRS/GRS/RA-GRS anyway;
//                Cold tier is used here). RA-GRS is the production choice.
//   Lifecycle  : Hot -> Cold at 90 days -> delete at 7 years.
//   Network    : private endpoint only; public access Disabled.
//                Audit window: pass IPs in temporaryAllowedIps and redeploy;
//                redeploy with [] to close it again.
//   Auth       : Entra ID only (shared key disabled) - so every SAS must be
//                a user delegation SAS, which can be revoked without key rotation.
// =====================================================================
param location string
param tags object

@description('3-24 lowercase letters/numbers, globally unique.')
param storageAccountName string

param subnetId string
param blobPrivateDnsZoneId string

@description('Containers to create. "audit" holds only what the auditor should see.')
param containerNames array = [
  'claims'
  'audit'
]

@description('Audit window ONLY: auditor public IP + your own (you need data-plane access to issue the SAS). Leave empty otherwise.')
param temporaryAllowedIps array = []

@description('Object ID of a user/group to grant Storage Blob Data Contributor (needed because shared key is off). Empty = skip.')
param dataContributorPrincipalId string = ''

@allowed([
  'User'
  'Group'
])
param dataContributorPrincipalType string = 'User'

var auditWindowOpen = !empty(temporaryAllowedIps)

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  tags: tags
  kind: 'StorageV2'
  sku: {
    name: 'Standard_GRS'
  }
  properties: {
    accessTier: 'Hot'
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false   // no anonymous containers, ever
    allowSharedKeyAccess: false    // Entra ID only; account-key SAS stops working
    defaultToOAuthAuthentication: true // portal uses your Entra identity, not keys
    publicNetworkAccess: auditWindowOpen ? 'Enabled' : 'Disabled'
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'None'
      ipRules: [for ip in temporaryAllowedIps: {
        value: ip
        action: 'Allow'
      }]
    }
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storage
  name: 'default'
  properties: {
    // GRS replicates deletes too - soft delete is what protects against human error.
    deleteRetentionPolicy: {
      enabled: true
      days: 14
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 14
    }
  }
}

resource containers 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = [for c in containerNames: {
  parent: blobService
  name: c
  properties: {
    publicAccess: 'None'
  }
}]

// Lifecycle management runs roughly once a day - tier changes are not instant.
resource lifecycle 'Microsoft.Storage/storageAccounts/managementPolicies@2023-05-01' = {
  parent: storage
  name: 'default'
  properties: {
    policy: {
      rules: [
        {
          name: 'cold-after-90d-delete-after-7y'
          enabled: true
          type: 'Lifecycle'
          definition: {
            filters: {
              blobTypes: [
                'blockBlob'
              ]
            }
            actions: {
              baseBlob: {
                tierToCold: {
                  daysAfterModificationGreaterThan: 90 // Cold: online, cheap, 90-day minimum stay
                }
                delete: {
                  daysAfterModificationGreaterThan: 2555 // 7 x 365
                }
              }
              snapshot: {
                delete: {
                  daysAfterCreationGreaterThan: 2555
                }
              }
            }
          }
        }
      ]
    }
  }
}

module blobPe 'private-endpoint.bicep' = {
  name: 'pe-${storageAccountName}-blob'
  params: {
    location: location
    tags: tags
    name: 'pe-${storageAccountName}-blob'
    subnetId: subnetId
    targetResourceId: storage.id
    groupId: 'blob'
    privateDnsZoneId: blobPrivateDnsZoneId
  }
}

// Storage Blob Data Contributor - data-plane role. Subscription Owner does NOT
// include data access, and with shared key off there is no key to fall back on.
var blobDataContributorRoleId = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'

resource dataContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(dataContributorPrincipalId)) {
  name: guid(storage.id, dataContributorPrincipalId, blobDataContributorRoleId)
  scope: storage
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', blobDataContributorRoleId)
    principalId: dataContributorPrincipalId
    principalType: dataContributorPrincipalType
  }
}

output storageAccountName string = storage.name
output storageAccountId string = storage.id
