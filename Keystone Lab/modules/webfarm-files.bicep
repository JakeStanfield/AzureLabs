// =====================================================================
// Azure Files share for the web farm - shared working storage both
// load-balanced web VMs mount (uploads in progress, shared config, reports).
// NOT the system of record: finished claim files belong in blob.
//
//   Redundancy : Standard_ZRS - the VMs are spread across zones 1 and 2,
//                so the share they both depend on must survive a zone loss too.
//   Network    : private endpoint only, public access Disabled. No exceptions.
//   Auth       : storage account key (web VMs aren't domain/Entra-joined).
//                That is WHY this is a separate account - the claims account
//                has shared key turned off. The key is written straight into
//                Key Vault and never appears in a file or deployment output.
//   SMB        : 3.1.1 only, AES-GCM channel encryption.
// =====================================================================
param location string
param tags object

@description('3-24 lowercase letters/numbers, globally unique.')
param storageAccountName string

param shareName string = 'webfarm'

@description('Provisioned size limit in GiB. Standard (pay-as-you-go) shares bill for used data, not quota.')
param shareQuotaGiB int = 100

param subnetId string
param filePrivateDnsZoneId string

@description('Existing Key Vault (same resource group) to store the account key in.')
param keyVaultName string
param keySecretName string = 'webfarm-storage-key'

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  tags: tags
  kind: 'StorageV2'
  sku: {
    name: 'Standard_ZRS'
  }
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true // required for key-based SMB mounts
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'None'
    }
  }
}

resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2023-05-01' = {
  parent: storage
  name: 'default'
  properties: {
    shareDeleteRetentionPolicy: {
      enabled: true
      days: 14
    }
    protocolSettings: {
      smb: {
        versions: 'SMB3.1.1' // Windows Server 2022 supports it; older SMB is refused
        channelEncryption: 'AES-128-GCM;AES-256-GCM'
        authenticationMethods: 'NTLMv2;Kerberos' // NTLMv2 = how key-based mounts authenticate
        kerberosTicketEncryption: 'AES-256'
      }
    }
  }
}

resource share 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-05-01' = {
  parent: fileService
  name: shareName
  properties: {
    shareQuota: shareQuotaGiB
    enabledProtocols: 'SMB'
    accessTier: 'TransactionOptimized'
  }
}

module filePe 'private-endpoint.bicep' = {
  name: 'pe-${storageAccountName}-file'
  params: {
    location: location
    tags: tags
    name: 'pe-${storageAccountName}-file'
    subnetId: subnetId
    targetResourceId: storage.id
    groupId: 'file'
    privateDnsZoneId: filePrivateDnsZoneId
  }
}

// Write the account key into Key Vault. This goes through ARM (control plane),
// so it works even though nobody ever sees or copies the key.
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource keySecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: keySecretName
  tags: tags
  properties: {
    value: storage.listKeys().keys[0].value
    contentType: 'Storage account key for ${storageAccountName}'
  }
}

output storageAccountName string = storage.name
output shareName string = share.name
output uncPath string = '\\\\${storage.name}.file.${environment().suffixes.storage}\\${share.name}'
