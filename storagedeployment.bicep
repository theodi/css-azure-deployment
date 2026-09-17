param config string = loadFileAsBase64('./configs/configFilesFix.json')
param configName string = 'config.json'
param location string = 'West Europe'
param shareName string = 'cssdata'
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
