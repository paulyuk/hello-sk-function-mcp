param principalId string
param roleDefinitionIds array
param searchAccountName string
@allowed(['ServicePrincipal', 'User'])
param principalType string = 'ServicePrincipal' // Default to ServicePrincipal, can be overridden with 'User' for Entra ID users

resource search 'Microsoft.Search/searchServices@2021-04-01-preview' existing = {
  name: searchAccountName
}

// Allow access from API to storage account using a managed identity and least priv Storage roles
resource storageRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = [for roleDefinitionId in roleDefinitionIds: {
  name: guid(search.id, principalId, roleDefinitionId)
  scope: search
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
    principalId: principalId
    principalType: principalType
  }
}]
