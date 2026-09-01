@description('Name of the App Service Plan')
param appServicePlanName string = 'asp-wapoinc-free'

@description('App Service Plan SKU. B1 is the minimum supported tier for managed certificates.')
@allowed([
  'B1'
])
param appServicePlanSkuName string = 'B1'

@description('Name of the Web App - must be globally unique')
param webAppName string = 'wapoinc-webapp-${uniqueString(subscription().id)}'

@description('Azure region')
param location string = resourceGroup().location

resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: appServicePlanSkuName
    tier: 'Basic'
    capacity: 1
  }
  properties: {
    reserved: false
  }
}

resource webApp 'Microsoft.Web/sites@2023-12-01' = {
  name: webAppName
  location: location
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
    }
  }
}

output defaultHostName string = webApp.properties.defaultHostName
output webAppName string = webApp.name
