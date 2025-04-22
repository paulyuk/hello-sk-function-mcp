targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
@allowed(['australiaeast', 'eastasia', 'eastus', 'eastus2', 'northeurope', 'southcentralus', 'southeastasia', 'swedencentral', 'uksouth', 'westus2', 'eastus2euap'])
@metadata({
  azd: {
    type: 'location'
  }
})
param location string
param vnetEnabled bool
param apiServiceName string = ''
param apiUserAssignedIdentityName string = ''
param applicationInsightsName string = ''
param appServicePlanName string = ''
param logAnalyticsName string = ''
param resourceGroupName string = ''
param storageAccountName string = ''
param vNetName string = ''
param disableLocalAuth bool = true

@description('Id of the user or app to assign application roles')
param principalId string = ''

param searchServiceName string = ''
param searchServiceSkuName string = 'standard'
param searchIndexName string = 'gptkbindex'

var aiHubName = 'hub-${resourceToken}'
var aiProjectName = 'proj-${resourceToken}'
var aiProjectFriendlyName = aiProjectName

param openAiServiceName string = ''
param openAiSkuName string = 'S0'

param gptDeploymentName string = 'chat'

@minLength(1)
@description('Name of the GPT model to deploy:')
@allowed([
  'gpt-4o'
  'gpt-4'
  'gpt-4o-mini'
])
param gptModelName string = 'gpt-4o-mini'

param azureOpenaiAPIVersion string = '2024-07-18'

@minLength(1)
@description('GPT model deployment type:')
@allowed([
  'Standard'
  'GlobalStandard'
])
param deploymentType string = 'GlobalStandard'

@minValue(10)
@description('Capacity of the GPT deployment:')
// You can increase this, but capacity is limited per model/region, so you will get errors if you go over
// https://learn.microsoft.com/en-us/azure/ai-services/openai/quotas-limits
param gptDeploymentCapacity int = 30

@minLength(1)
@description('Name of the Text Embedding model to deploy:')
@allowed([
  'text-embedding-ada-002'
])
param embeddingModel string = 'text-embedding-ada-002'

@allowed([ 'consumption', 'flexconsumption' ])
param azFunctionHostingPlanType string = 'flexconsumption'

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 'azd-env-name': environmentName }
var functionAppName = !empty(apiServiceName) ? apiServiceName : '${abbrs.webSitesFunctions}api-${resourceToken}'
var deploymentStorageContainerName = 'app-package-${take(functionAppName, 32)}-${take(toLower(uniqueString(functionAppName, resourceToken)), 7)}'

// Organize resources in a resource group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

module openAi 'core/ai/cognitiveservices.bicep' = {
  name: 'openai'
  scope: rg
  params: {
    name: !empty(openAiServiceName) ? openAiServiceName : '${abbrs.cognitiveServicesAccounts}${resourceToken}'
    location: location
    tags: tags
    publicNetworkAccess: vnetEnabled ? 'Disabled' : 'Enabled'
    sku: {
      name: openAiSkuName
    }
    deployments: [
      {
        name: embeddingModel
        model: embeddingModel
        sku: {
          name: 'Standard'
          capacity: 80
        }
        raiPolicyName: 'Microsoft.Default'
      }
      {
        name: gptDeploymentName
        model: gptModelName
        sku: {
          name: deploymentType
          capacity: gptDeploymentCapacity
        }
        raiPolicyName: 'Microsoft.Default'
      }
    ]
  }
}
 
module searchService 'core/search/search-services.bicep' = {
  name: 'search-service'
  scope: rg
  params: {
    name: !empty(searchServiceName) ? searchServiceName : 'gptkb-${resourceToken}'
    location: location
    tags: tags
    authOptions: {
      aadOrApiKey: {
        aadAuthFailureMode: 'http401WithBearerChallenge'
      }
    }
    sku: {
      name: searchServiceSkuName
    }
    semanticSearch: 'free'
  }
}

// Deploy the AI Hub and project using foundryservices module
module foundry 'core/ai/foundryservices.bicep' = {
  name: 'foundry'
  scope: rg
  params: {
    name: aiHubName
    projectName: aiProjectFriendlyName
    location: location
    tags: tags
    friendlyName: aiHubName
    projectFriendlyName: aiProjectName
    description: 'AI Hub'
    userAssignedIdentityId: apiUserAssignedIdentity.outputs.identityId
    
    // Resources - use names instead of IDs
    storageAccountName: storage.outputs.name
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    containerRegistryName: 'acr${resourceToken}'
    
    // AI Services
    aiServicesEndpoint: openAi.outputs.endpoint
    aiServicesName: openAi.outputs.name
    
    // Search
    aiSearchName: searchService.outputs.name
  }
}

// User assigned managed identity to be used by the function app to reach storage and service bus
module apiUserAssignedIdentity './core/identity/userAssignedIdentity.bicep' = {
  name: 'apiUserAssignedIdentity'
  scope: rg
  params: {
    location: location
    tags: tags
    identityName: !empty(apiUserAssignedIdentityName) ? apiUserAssignedIdentityName : '${abbrs.managedIdentityUserAssignedIdentities}api-${resourceToken}'
  }
}

// The application backend is a function app
module appServicePlan './core/host/appserviceplan.bicep' = {
  name: 'appserviceplan'
  scope: rg
  params: {
    name: !empty(appServicePlanName) ? appServicePlanName : '${abbrs.webServerFarms}${resourceToken}'
    location: location
    tags: tags
    sku: {
      name: 'FC1'
      tier: 'FlexConsumption'
    }
  }
}

module api './app/api.bicep' = {
  name: 'api'
  scope: rg
  params: {
    name: functionAppName
    location: location
    tags: tags
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    appServicePlanId: appServicePlan.outputs.id
    runtimeName: 'python'
    runtimeVersion: '3.11'
    storageAccountName: storage.outputs.name
    deploymentStorageContainerName: deploymentStorageContainerName
    identityId: apiUserAssignedIdentity.outputs.identityId
    identityClientId: apiUserAssignedIdentity.outputs.identityClientId
    appSettings: {
      AZURE_AI_INFERENCE_ENDPOINT: openAi.outputs.endpoint
      AZURE_CLIENT_ID: apiUserAssignedIdentity.outputs.identityClientId
      AZURE_OPENAI_API_VERSION: azureOpenaiAPIVersion
      AZURE_OPENAI_DEPLOYMENT_NAME: gptDeploymentName
    }
    virtualNetworkSubnetId: !vnetEnabled ? '' : serviceVirtualNetwork.outputs.appSubnetID
  }
}

// Backing storage for Azure functions api
module storage './core/storage/storage-account.bicep' = {
  name: 'storage'
  scope: rg
  params: {
    name: !empty(storageAccountName) ? storageAccountName : '${abbrs.storageStorageAccounts}${resourceToken}'
    location: location
    tags: tags
    containers: [{name: deploymentStorageContainerName}, {name: 'snippets'}]
    publicNetworkAccess: vnetEnabled ? 'Disabled' : 'Enabled'
    networkAcls: !vnetEnabled ? {} : {
      defaultAction: 'Deny'
    }
  }
}

var StorageBlobDataOwner = 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
var StorageQueueDataContributor = '974c5e8b-45b9-4653-ba55-5f855dd0fb88'

// Allow access from api to blob storage using a managed identity
module blobRoleAssignmentApi 'app/storage-Access.bicep' = {
  name: 'blobRoleAssignmentapi'
  scope: rg
  params: {
    storageAccountName: storage.outputs.name
    roleDefinitionID: StorageBlobDataOwner
    principalID: apiUserAssignedIdentity.outputs.identityPrincipalId
  }
}

// Allow access from api to queue storage using a managed identity
module queueRoleAssignmentApi 'app/storage-Access.bicep' = {
  name: 'queueRoleAssignmentapi'
  scope: rg
  params: {
    storageAccountName: storage.outputs.name
    roleDefinitionID: StorageQueueDataContributor
    principalID: apiUserAssignedIdentity.outputs.identityPrincipalId
  }
}

// Virtual Network & private endpoint to blob storage
module serviceVirtualNetwork 'app/vnet.bicep' =  if (vnetEnabled) {
  name: 'serviceVirtualNetwork'
  scope: rg
  params: {
    location: location
    tags: tags
    vNetName: !empty(vNetName) ? vNetName : '${abbrs.networkVirtualNetworks}${resourceToken}'
  }
}

module storagePrivateEndpoint 'app/storage-PrivateEndpoint.bicep' = if (vnetEnabled) {
  name: 'servicePrivateEndpoint'
  scope: rg
  params: {
    location: location
    tags: tags
    virtualNetworkName: !empty(vNetName) ? vNetName : '${abbrs.networkVirtualNetworks}${resourceToken}'
    subnetName: !vnetEnabled ? '' : serviceVirtualNetwork.outputs.peSubnetName
    resourceName: storage.outputs.name
  }
}

module openAiPrivateEndpoint 'app/openai-privateendpoint.bicep' = if (vnetEnabled){
  name: 'openAiPrivateEndpoint'
  scope: rg
  params: {
    location: location
    tags: tags
    virtualNetworkName: !empty(vNetName) ? vNetName : '${abbrs.networkVirtualNetworks}${resourceToken}'
    openaiSubnetName: !vnetEnabled ? '' : serviceVirtualNetwork.outputs.peSubnetName
    openAiResourceId: openAi.outputs.id
  }
}

// Monitor application with Azure Monitor
module monitoring './core/monitor/monitoring.bicep' = {
  name: 'monitoring'
  scope: rg
  params: {
    location: location
    tags: tags
    logAnalyticsName: !empty(logAnalyticsName) ? logAnalyticsName : '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    applicationInsightsName: !empty(applicationInsightsName) ? applicationInsightsName : '${abbrs.insightsComponents}${resourceToken}'
    disableLocalAuth: disableLocalAuth  
  }
}

var monitoringRoleDefinitionId = '3913510d-42f4-4e42-8a64-420c390055eb' // Monitoring Metrics Publisher role ID

// Allow access from api to application insights using a managed identity
module appInsightsRoleAssignmentApi './core/monitor/appinsights-access.bicep' = {
  name: 'appInsightsRoleAssignmentapi'
  scope: rg
  params: {
    appInsightsName: monitoring.outputs.applicationInsightsName
    roleDefinitionID: monitoringRoleDefinitionId
    principalID: apiUserAssignedIdentity.outputs.identityPrincipalId
  }
}

// Allow access from api to Azure AI Services using a managed identity
module openAiRoleUserAssignedIdentity 'app/openai-access.bicep' = {
  scope: rg
  name: 'openai-roles-uami'
  params: {
    principalId: apiUserAssignedIdentity.outputs.identityPrincipalId
    openAiAccountResourceName: openAi.outputs.name
    roleDefinitionIds: ['a97b65f3-24c7-4388-baec-2e87135dc908'] // Cognitive Services User
  }
}

// Allow access from api to Azure AI Services using the interactive Entra user identity
module openAiRoleEntraUser 'app/openai-access.bicep' = {
  scope: rg
  name: 'openai-roles-entra'
  params: {
    principalId: principalId
    openAiAccountResourceName: openAi.outputs.name
    roleDefinitionIds: ['a97b65f3-24c7-4388-baec-2e87135dc908'] // Cognitive Services User
    principalType: 'User' // Always use User type for Entra user identity
  }
}

// Allow access from api to Azure Search using a managed identity
module searchRoleUserAssignedIdentity 'app/search-access.bicep' = {
  scope: rg
  name: 'search-roles-uami'
  params: {
    principalId: apiUserAssignedIdentity.outputs.identityPrincipalId
    roleDefinitionIds: ['7ca78c08-252a-4471-8644-bb5ff32d4ba0', '8ebe5a00-799e-43f5-93ac-243d3dce84a7', '1407120a-92aa-4202-b7e9-c0e197c71c8f']  // Search Index Data Contributor, Search Index Data Owner, Search Index Data Reader
    searchAccountName: searchService.outputs.name
  }
}

// Allow access from api to Azure Search using the interactive Entra user identity
module searchRoleEntraUserIdentity 'app/search-access.bicep' = {
  scope: rg
  name: 'search-roles'
  params: {
    principalId: principalId
    roleDefinitionIds: ['7ca78c08-252a-4471-8644-bb5ff32d4ba0', '8ebe5a00-799e-43f5-93ac-243d3dce84a7', '1407120a-92aa-4202-b7e9-c0e197c71c8f']  // Search Index Data Contributor, Search Index Data Owner, Search Index Data Reader
    searchAccountName: searchService.outputs.name
    principalType: 'User' // Always use User type for Entra user identity
  }
}

// App outputs
output APPLICATIONINSIGHTS_CONNECTION_STRING string = monitoring.outputs.applicationInsightsConnectionString
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output SERVICE_API_NAME string = api.outputs.SERVICE_API_NAME
output AZURE_FUNCTION_NAME string = api.outputs.SERVICE_API_NAME
output AZURE_OPENAI_DEPLOYMENT_NAME string = gptDeploymentName
output AZURE_AI_INFERENCE_ENDPOINT string = openAi.outputs.endpoint
output AZURE_OPENAI_API_VERSION string = azureOpenaiAPIVersion

