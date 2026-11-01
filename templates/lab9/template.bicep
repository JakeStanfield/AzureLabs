param subscriptionId string
param name string
param location string
param environmentId string
param containers array

@secure()
param secrets object = {
  arrayValue: []
}
param registries array
param ingress object
param environmentName string
param workspaceName string
param workspaceLocation string

resource name_resource 'Microsoft.App/containerapps@2025-10-02-preview' = {
  name: name
  kind: 'containerapps'
  location: location
  properties: {
    environmentId: environmentId
    configuration: {
      secrets: secrets.arrayValue
      registries: registries
      activeRevisionsMode: 'Single'
      ingress: ingress
    }
    template: {
      containers: containers
      scale: {
        minReplicas: 0
      }
    }
    workloadProfileName: 'Consumption'
  }
  dependsOn: [
    environment
  ]
}

resource environment 'Microsoft.App/managedEnvironments@2025-10-02-preview' = {
  name: environmentName
  location: location
  properties: {
    appLogsConfiguration: {
      destination: null
      logAnalyticsConfiguration: null
    }
    publicNetworkAccess: 'Enabled'
    workloadProfiles: [
      {
        name: 'Consumption'
        workloadProfileType: 'Consumption'
      }
    ]
  }
  dependsOn: []
}
