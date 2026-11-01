// Resource-group-scoped pieces of the cost guard.
param location string

@secure()
param webhookUri string

@description('Create the action group (false on the first pass, before the webhook exists).')
param deployAlerts bool

var suffix = uniqueString(subscription().id, resourceGroup().id)
var automationAccountName = 'cost-guard-aa-${suffix}'
var storageAccountName = 'costguard${suffix}'
var runbookName = 'Backup-And-Deallocate'
var backupContainer = 'template-backups'
var blobDataContributorRoleId = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    supportsHttpsTrafficOnly: true
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storage
  name: 'default'
}

resource container 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: backupContainer
}

resource automation 'Microsoft.Automation/automationAccounts@2023-11-01' = {
  name: automationAccountName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    sku: {
      name: 'Basic'
    }
  }
}

resource storageVar 'Microsoft.Automation/automationAccounts/variables@2023-11-01' = {
  parent: automation
  name: 'BackupStorageAccount'
  properties: {
    isEncrypted: false
    value: '"${storage.name}"'
  }
}

resource containerVar 'Microsoft.Automation/automationAccounts/variables@2023-11-01' = {
  parent: automation
  name: 'BackupContainer'
  properties: {
    isEncrypted: false
    value: '"${backupContainer}"'
  }
}

// Content is uploaded and published by deploy.ps1.
resource runbook 'Microsoft.Automation/automationAccounts/runbooks@2023-11-01' = {
  parent: automation
  name: runbookName
  location: location
  properties: {
    runbookType: 'PowerShell'
    logProgress: false
    logVerbose: false
  }
}

resource blobWriter 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storage.id, automation.id, blobDataContributorRoleId)
  scope: storage
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', blobDataContributorRoleId)
    principalId: automation.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = if (deployAlerts) {
  name: 'cost-guard-shutdown'
  location: 'global'
  properties: {
    groupShortName: 'costguard'
    enabled: true
    webhookReceivers: [
      {
        name: 'shutdown-runbook'
        serviceUri: webhookUri
        useCommonAlertSchema: false
      }
    ]
  }
}

output automationAccountName string = automation.name
output automationPrincipalId string = automation.identity.principalId
output storageAccountName string = storage.name
output runbookName string = runbook.name
output actionGroupId string = deployAlerts ? actionGroup.id : ''
