// =====================================================================
// Require a CostCenter tag whose value is one of an allowed list.
// Replaces the built-in "Require a tag and its value on resources", which
// can only compare against a single exact value.
// Deploy with:  az deployment mg create --management-group-id KeystoneLabMG --location eastus2 --template-file costcenter-tag-policy.bicep
// =====================================================================
targetScope = 'managementGroup'

param allowedCostCenters array = [
  '101'
  '201'
  '301'
  '401'
]

@description('Enroll matches the current assignment and does not block deployments. Use Default to deny non-compliant resources.')
param enforcementMode string = 'Enroll'

resource definition 'Microsoft.Authorization/policyDefinitions@2023-04-01' = {
  name: 'require-costcenter-tag-in-list'
  properties: {
    displayName: 'Require a CostCenter tag from the allowed list'
    description: 'Denies resources whose CostCenter tag is missing or not one of the allowed values.'
    policyType: 'Custom'
    // Indexed = only resources that support tags. Resource groups are not evaluated.
    mode: 'Indexed'
    parameters: {
      allowedValues: {
        type: 'Array'
        metadata: {
          displayName: 'Allowed CostCenter values'
        }
      }
    }
    policyRule: {
      if: {
        anyOf: [
          {
            field: 'tags[CostCenter]'
            exists: 'false'
          }
          {
            field: 'tags[CostCenter]'
            notIn: '[parameters(\'allowedValues\')]'
          }
        ]
      }
      then: {
        effect: 'deny'
      }
    }
  }
}

resource assignment 'Microsoft.Authorization/policyAssignments@2025-01-01' = {
  name: 'require-costcenter-tag'
  properties: {
    displayName: 'Require a CostCenter tag from the allowed list'
    policyDefinitionId: definition.id
    enforcementMode: enforcementMode
    parameters: {
      allowedValues: {
        value: allowedCostCenters
      }
    }
  }
}
