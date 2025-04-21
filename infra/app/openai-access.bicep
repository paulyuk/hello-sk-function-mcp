param principalId string
param roleDefinitionIds array
param openAiAccountResourceName string
@allowed(['ServicePrincipal', 'User'])
param principalType string = 'ServicePrincipal' // Default to ServicePrincipal, can be overridden with 'User' for Entra ID users

resource account 'Microsoft.CognitiveServices/accounts@2023-05-01' existing = {
  name: openAiAccountResourceName
}

resource role 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for roleDefinitionId in roleDefinitionIds: {
  name: guid(subscription().id, resourceGroup().id, principalId, roleDefinitionId)
  scope: account
  properties: {
    principalId: principalId
    principalType: principalType
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
  }
}]
