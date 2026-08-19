param siteName string = 'cssdeployment'
param planName string = 'cssdeployment'
param storageName string = 'cssstoragenew2'
param location string = 'West Europe'

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageName
  location: location
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'

  resource files 'fileServices' = {
    name: 'default'

    resource share 'shares' = {
      name: 'cssdata'
    }
  }
}

resource plan 'Microsoft.Web/serverfarms@2024-11-01' = {
  name: planName
  location: location
  sku: { name: 'B3' }
  kind: 'linux'
    properties: {
      reserved: true
  }
}

resource site 'Microsoft.Web/sites@2024-11-01' = {
  name: siteName
  location: 'West Europe'
  kind: 'app,linux'
  properties: {
    serverFarmId: plan.id
    siteConfig: {
      linuxFxVersion: 'sitecontainers'
    }
    publicNetworkAccess: 'Enabled'
  }
}

resource siteConfig 'Microsoft.Web/sites/config@2024-11-01' = {
  parent: site
  name: 'web'
  properties: {
    publicNetworkAccess: 'Enabled'
    azureStorageAccounts: {
      cssdata: {
        type: 'AzureFiles'
        accountName: storageName
        shareName: 'cssdata'
        mountPath: '/cssdata'
        protocol: 'Smb'
        accessKey: storage.listKeys().keys[0].value
      }
    }
  }
}

var baseUrl string = 'https://${site.properties.defaultHostName}/'

resource siteContainer 'Microsoft.Web/sites/sitecontainers@2024-11-01' = {
  parent: site
  name: 'main'
  properties: {
    image: 'index.docker.io/solidproject/community-server:latest'
    targetPort: '3000'
    isMain: true
    startUpCommand: '--loggingLevel debug --rootFilePath /cssdata --config /cssdata/config.json --baseUrl ${baseUrl}'
    authType: 'Anonymous'
    volumeMounts: []
    environmentVariables: []
  }
}
