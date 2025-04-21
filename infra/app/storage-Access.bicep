param principalID string
param roleDefinitionID string
param storageAccountName string
@allowed(['ServicePrincipal', 'User'])
param principalType string = 'ServicePrincipal' // Default to ServicePrincipal, can be overridden with 'User' for Entra ID users

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-09-01' existing = {
  name: storageAccountName
}

// Allow access from API to storage account using a managed identity and least priv Storage roles
resource storageRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(storageAccount.id, principalID, roleDefinitionID)
  scope: storageAccount
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionID)
    principalId: principalID
    principalType: principalType
  }
}

output ROLE_ASSIGNMENT_NAME string = storageRoleAssignment.name
