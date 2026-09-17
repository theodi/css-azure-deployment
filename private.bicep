param configName string = 'config.json'
param location string = 'West Europe'
param planName string = 'cssdeployment'
param planSku string = 'B3'
param shareName string = 'cssdata'
param siteName string = 'cssdeployment'
param storageName string = 'cssstoragenew2'
param vnetName string = 'css-vnet'
param subnetFilesName string = 'css-subnet'
param subnetWebName string = 'css-web-subnet'
param privateFilesDnsZoneName string = 'privatelink.file.${environment().suffixes.storage}'

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: subnetFilesName
        properties: {
          addressPrefix: '10.0.1.0/28'
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Disabled'
        }
      }
      {
        name: subnetWebName
        properties: {
          addressPrefix: '10.0.2.0/28'
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Disabled'
          delegations: [
            {
              name: 'webapp'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
        }
      }
    ]
  }
}

resource storagePrivateEndpointFiles 'Microsoft.Network/privateEndpoints@2023-09-01' = {
  name: '${storageName}-pe'
  location: location
  properties: {
    subnet: {
      id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, subnetFilesName)
    }
    privateLinkServiceConnections: [
      {
        name: '${storageName}-pls'
        properties: {
          privateLinkServiceId: storage.id
          groupIds: [
            'file'
          ]
        }
      }
    ]
  }
}

resource privateFilesDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateFilesDnsZoneName
  location: 'global'
}

resource privateStorageFileDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateFilesDnsZone
  name: '${privateFilesDnsZoneName}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

resource privateEndpointStorageFilePrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-05-01' = {
  parent: storagePrivateEndpointFiles
  name: 'filePrivateDnsZoneGroup'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config'
        properties: {
          privateDnsZoneId: privateFilesDnsZone.id
        }
      }
    ]
  }
}

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    publicNetworkAccess: 'Disabled'
    allowBlobPublicAccess: false
    networkAcls: {
      bypass: 'None'
      defaultAction: 'Deny'
    }
  }

  resource files 'fileServices' = {
    name: 'default'

    resource share 'shares' = {
      name: shareName
    }
  }
}

var storageKey = storage.listKeys().keys[0].value

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
    outboundVnetRouting: {
      allTraffic: false
      applicationTraffic: true
      backupRestoreTraffic: false
      contentShareTraffic: false
      imagePullTraffic: false
    }
  }
}

resource siteConfig 'Microsoft.Web/sites/config@2024-11-01' = {
  parent: site
  name: 'web'
  properties: {
    publicNetworkAccess: 'Enabled'
    vnetRouteAllEnabled: true
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
    startUpCommand: '--loggingLevel debug --rootFilePath /${shareName} --config /${shareName}/${configName} --baseUrl ${baseUrl}'
    authType: 'Anonymous'
  }
}

resource siteNetworkConfig 'Microsoft.Web/sites/networkConfig@2024-11-01' = {
  parent: site
  name: 'virtualNetwork'
  properties: {
    subnetResourceId: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, subnetWebName)
    swiftSupported: true
  }
}
