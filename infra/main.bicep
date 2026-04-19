targetScope = 'subscription'

@minLength(1)
@maxLength(64)
param environmentName string
@minLength(1)
param location string

var abbrs = loadJsonContent('abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 'azd-env-name': environmentName }

// 1. Reference the existing Resource Group
resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-11-01' = {
  name: 'rg-rag-nick-banking-0329'
  location: location
  tags: tags
}

// 2. Monitoring
module monitoring 'core/monitor/monitoring.bicep' = {
  name: 'monitoring'
  scope: resourceGroup
  params: {
    location: location
    tags: tags
    applicationInsightsName: '${abbrs.insightsComponents}${resourceToken}'
    logAnalyticsName: '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
  }
}
// 3. Container Apps Infrastructure
module containerApps 'core/host/container-apps.bicep' = {
  name: 'container-apps'
  scope: resourceGroup
  params: {
    name: 'app'
    // REMOVE targetPort: 8000 from here!
    location: location
    containerAppsEnvironmentName: '${environmentName}-aca-env'
    containerRegistryName: 'acrnickbankingdemo'
    logAnalyticsWorkspaceName: monitoring.outputs.logAnalyticsWorkspaceName
    workloadProfile: 'Consumption'
    usePrivateIngress: false 
  }
}

// 4. The Backend Service (KEEP IT HERE)
module backend 'core/host/container-app-upsert.bicep' = {
  name: 'backend'
  scope: resourceGroup
  params: {
    name: 'aca-backend-banking-demo'
    location: location
    tags: union(tags, { 'azd-service-name': 'backend' })
    containerRegistryName: 'acrnickbankingdemo'
    containerAppsEnvironmentName: containerApps.outputs.environmentName
    exists: false 
    targetPort: 8000 // This is the correct place
    env: {
       // ... your env vars
    }
  }
}

output AZURE_CONTAINER_REGISTRY_ENDPOINT string = 'acrnickbankingdemo.azurecr.io'