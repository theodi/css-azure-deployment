param configName string = 'config.json'
param location string = 'West Europe'
param planName string = 'cssdeployment'
param planSku string = 'B3'
param shareName string = 'cssdata'
param siteName string = 'cssdeployment'
param storageName string = 'cssstoragenew2'

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'

  resource files 'fileServices' = {
    name: 'default'

    resource share 'shares' = {
      name: shareName
    }
  }
}

var storageKey = storage.listKeys().keys[0].value
var config = loadFileAsBase64('./config.json')

resource deploymentScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: 'UploadConfig'
  location: location
  kind: 'AzureCLI'
  properties: {
    azCliVersion: '2.89.0'
    arguments: storageKey
    scriptContent: 'echo "${config}" | base64 -d > ${configName} && az storage file upload --account-name ${storageName} --path ${configName} --share-name ${shareName} --source ./${configName} --account-key ${storageKey} --content-type application/json'
    retentionInterval: 'PT1H'
  }
  dependsOn: [
    storage
  ]
}

resource plan 'Microsoft.Web/serverfarms@2024-11-01' = {
  name: planName
  location: location
  sku: {
    name: planSku
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

resource site 'Microsoft.Web/sites@2024-11-01' = {
  name: siteName
  location: location
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
        shareName: shareName
        mountPath: '/${shareName}'
        protocol: 'Smb'
        accessKey: storageKey
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
    startUpCommand: '--loggingLevel debug --rootFilePath /${shareName} --config /${shareName}/config.json --baseUrl ${baseUrl}'
    authType: 'Anonymous'
  }
}
