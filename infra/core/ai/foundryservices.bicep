targetScope = 'resourceGroup'

param name string
param projectName string
param location string
param tags object = {}
param friendlyName string = name
param projectFriendlyName string = projectName
param description string = 'AI Hub'

// Change from ID params to name params
param storageAccountName string
param applicationInsightsName string
param containerRegistryName string

param aiServicesEndpoint string
param aiServicesName string
param aiServicesResourceGroup string = resourceGroup().name

param aiSearchName string
param aiSearchResourceGroup string = resourceGroup().name

// Optional user-assigned identity parameter
param userAssignedIdentityId string = ''

// Look up existing resources using the provided names
resource storageAccount 'Microsoft.Storage/storageAccounts@2021-09-01' existing = {
  name: storageAccountName
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: applicationInsightsName
}

var containerRegistryNameCleaned = replace(containerRegistryName, '-', '')

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2021-09-01' = {
  name: containerRegistryNameCleaned
  location: location
  sku: {
    name: 'Premium'
  }
  properties: {
    adminUserEnabled: true
    dataEndpointEnabled: false
    networkRuleBypassOptions: 'AzureServices'
    networkRuleSet: {
      defaultAction: 'Deny'
    }
    policies: {
      quarantinePolicy: {
        status: 'enabled'
      }
      retentionPolicy: {
        status: 'enabled'
        days: 7
      }
      trustPolicy: {
        status: 'disabled'
        type: 'Notary'
      }
    }
    publicNetworkAccess: 'Disabled'
    zoneRedundancy: 'Disabled'
  }
}

resource aiServices 'Microsoft.CognitiveServices/accounts@2023-05-01' existing = {
  name: aiServicesName
  scope: resourceGroup(aiServicesResourceGroup)
}

resource searchService 'Microsoft.Search/searchServices@2022-09-01' existing = {
  name: aiSearchName
  scope: resourceGroup(aiSearchResourceGroup)
}

// Add SystemAssigned and optional UserAssigned identity
resource aiHub 'Microsoft.MachineLearningServices/workspaces@2023-08-01-preview' = {
  name: name
  location: location
  identity: {
    type: empty(userAssignedIdentityId) ? 'SystemAssigned' : 'SystemAssigned,UserAssigned'
    userAssignedIdentities: empty(userAssignedIdentityId) ? null : {
      '${userAssignedIdentityId}': {}
    }
  }
  properties: {
    // organization
    friendlyName: friendlyName
    description: description

    // dependent resources - use the IDs from the looked-up resources
    storageAccount: storageAccount.id
    applicationInsights: applicationInsights.id
    containerRegistry: containerRegistry.id
  }
  kind: 'hub'

  resource aiServicesConnection 'connections@2024-07-01-preview' = {
    name: '${name}-connection-AzureOpenAI'
    properties: {
      category: 'AIServices'
      target: aiServicesEndpoint
      authType: 'ApiKey'  // Changed from ManagedIdentity to ApiKey
      isSharedToAll: true
      credentials: {
        key: listKeys(aiServices.id, aiServices.apiVersion).key1
      }
      metadata: {
        ApiType: 'Azure'
        ResourceId: aiServices.id
      }
    }
  }
  
  resource aiSearchConnection 'connections@2024-07-01-preview' = {
    name: '${name}-connection-AzureAISearch'
    properties: {
      category: 'CognitiveSearch'
      target: 'https://${aiSearchName}.search.windows.net'
      authType: 'ApiKey'  // Changed from ManagedIdentity to ApiKey
      isSharedToAll: true
      credentials: {
        key: listAdminKeys(searchService.id, searchService.apiVersion).primaryKey
      }
      metadata: {
        type: 'azure_ai_search'
        ApiType: 'Azure'
        ResourceId: searchService.id
        ApiVersion: '2024-05-01-preview'
        DeploymentApiVersion: '2023-11-01'
      }
    }
  }
}

resource aiHubProject 'Microsoft.MachineLearningServices/workspaces@2024-01-01-preview' = {
  name: projectName
  location: location
  kind: 'Project'
  identity: {
    type: empty(userAssignedIdentityId) ? 'SystemAssigned' : 'SystemAssigned,UserAssigned'
    userAssignedIdentities: empty(userAssignedIdentityId) ? null : {
      '${userAssignedIdentityId}': {}
    }
  }
  properties: {
    friendlyName: projectFriendlyName
    hubResourceId: aiHub.id
  }
}


output hubId string = aiHub.id
output projectId string = aiHubProject.id
output hubPrincipalId string = aiHub.identity.principalId
output projectPrincipalId string = aiHubProject.identity.principalId
