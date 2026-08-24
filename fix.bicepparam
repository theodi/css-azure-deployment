using 'main.bicep'

param configName = 'configFilesFix.json'
param location = 'West Europe'
param planName = 'cssdeploymentfix'
param planSku = 'B3'
param shareName = 'cssdatafix'
param siteName = 'cssdeploymentfix'
param storageName = 'cssstoragefix'
param config = loadFileAsBase64('./configFilesFix.json')
