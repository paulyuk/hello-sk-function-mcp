param name string
param location string = resourceGroup().location
param tags object = {}
 
param customSubDomainName string = name
param deployments array = []
param kind string = 'AIServices'
param publicNetworkAccess string = 'Enabled'
param sku object = {
  name: 'S0'
}
 
resource account 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: name
  location: location
  tags: tags
  kind: kind
  properties: {
    customSubDomainName: name
    networkAcls : {
      defaultAction: publicNetworkAccess == 'Enabled' ? 'Allow' : 'Deny'
      virtualNetworkRules: []
      ipRules: []
  }
    publicNetworkAccess: publicNetworkAccess
  }
  sku: sku
}
 
@batchSize(1)
resource deployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = [for deployment in deployments: {
  parent: account
  name: deployment.name
  sku: {
    name: deployment.sku.name
    capacity: deployment.sku.capacity
  }
  properties: {
    raiPolicyName: deployment.?raiPolicyName ?? null
    model: {
      format: 'OpenAI'
      name: deployment.model
    }
  }
}]
 
output endpoint string = account.properties.endpoint
output id string = account.id
output name string = account.name
output location string = account.location
