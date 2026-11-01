// Cost guard: monthly budget that backs up every resource group as an ARM
// template and then deallocates compute once actual spend hits the limit.
// Deploy with deploy.ps1 (it also uploads the runbook and creates the webhook).
targetScope = 'subscription'

@description('Monthly budget in the billing currency.')
param budgetAmount int = 10

@description('Address that receives the budget alert emails.')
param alertEmail string

param location string = 'eastus'
param resourceGroupName string = 'cost-guard-rg'

@description('First day of the month the budget starts in (yyyy-MM-01).')
param budgetStartDate string = '${utcNow('yyyy-MM')}-01'

@secure()
@description('Automation webhook URI for the shutdown runbook. Leave empty on the first pass.')
param webhookUri string = ''

var contributorRoleId = 'b24988ac-6180-42a0-ab88-20f7382dd24c'

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
}

module guard 'guard.bicep' = {
  name: 'cost-guard-resources'
  scope: rg
  params: {
    location: location
    webhookUri: webhookUri
    deployAlerts: !empty(webhookUri)
  }
}

// The runbook needs Contributor to export templates and stop resources.
resource automationContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, 'cost-guard-automation', contributorRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', contributorRoleId)
    principalId: guard.outputs.automationPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource budget 'Microsoft.Consumption/budgets@2023-05-01' = if (!empty(webhookUri)) {
  name: 'monthly-${budgetAmount}-usd-shutdown'
  properties: {
    category: 'Cost'
    amount: budgetAmount
    timeGrain: 'Monthly'
    timePeriod: {
      startDate: budgetStartDate
    }
    notifications: {
      actual_GreaterThanOrEqualTo_80_Percent: {
        enabled: true
        operator: 'GreaterThanOrEqualTo'
        threshold: 80
        thresholdType: 'Actual'
        contactEmails: [alertEmail]
      }
      actual_GreaterThanOrEqualTo_100_Percent: {
        enabled: true
        operator: 'GreaterThanOrEqualTo'
        threshold: 100
        thresholdType: 'Actual'
        contactEmails: [alertEmail]
        contactGroups: [guard.outputs.actionGroupId]
      }
    }
  }
}

output automationAccountName string = guard.outputs.automationAccountName
output storageAccountName string = guard.outputs.storageAccountName
output resourceGroupName string = rg.name
