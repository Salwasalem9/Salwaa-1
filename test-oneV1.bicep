@description('admin password')
@secure()

param adminPassword string

@description('admin username')
param adminUsername string

@description('disk storage type')
@allowed([
  'StandardSSD_LRS'
  'Standard_LRS'
  'Premium_LRS'
])
param diskType string = 'Standard_LRS'

@description('Network interface name prefix')
param nicNamePrefix string = ''

@description(' How many VMs to provision')
@minValue(1)
@maxValue(6)
param vmCount int 

@description('VM name prefix')
param vmNamePrefix string = 'lab01-vm'

@description('VM size')
param vmSize string = 'Standard_D2s_v3'

@description('Type the virtual macvhine name Virtual network name')
param vnetName string = 'lab01-vnet'

@description('Public IP Name ')
param pipName string = 'pip01'

var commands = '#!/bin/sh\ntouch /etc/yum.repos.d/mariadb.repo\necho "[mariadb]" >> /etc/yum.repos.d/mariadb.repo\necho "name = MariaDB" >> /etc/yum.repos.d/mariadb.repo\necho "baseurl = http://yum.mariadb.org/10.4/centos7-amd64" >> /etc/yum.repos.d/mariadb.repo\necho "gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB" >> /etc/yum.repos.d/mariadb.repo\necho "gpgcheck=1" >> /etc/yum.repos.d/mariadb.repo\nyum install MariaDB-server MariaDB-client -y\nservice firewalld stop\nsystemctl disable firewalld'
var subnet0Name = 'web'
var vnetID = vnetName_resource.id
var subnetRef = '${vnetID}/subnets/${subnet0Name}'
var webNetworkSecurityGroupName_var = 'az30305a-web-nsg'
var storageAccountName_var = 'az30005a${uniqueString(subscription().subscriptionId, resourceGroup().id, deployment().name)}'
var storageAccountType = 'Standard_LRS'
var imageReference = {
  publisher: 'RedHat'
  offer: 'RHEL'
  sku: '7.8'
  version: 'latest'
}

resource nicNamePrefix_resource 'Microsoft.Network/networkInterfaces@2020-11-01' = [for i in range(0, vmCount): {
  name: concat(nicNamePrefix, i)
  location: resourceGroup().location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnetRef
          }
          publicIPAddress: {
            id: resourceId('Microsoft.Network/publicIPAddresses', concat(pipName, i))
          }
        }
      }
    ]
  }
  dependsOn: [
    vnetName_resource
  ]
}]

resource vmNamePrefix_resource 'Microsoft.Compute/virtualMachines@2021-11-01' = [for i in range(0, vmCount): {
  name: concat(vmNamePrefix, i)
  location: resourceGroup().location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: concat(vmNamePrefix, i)
      adminUsername: adminUsername
      adminPassword: adminPassword
      customData: base64(concat(commands))
    }
    storageProfile: {
      imageReference: imageReference
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: diskType
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: resourceId('Microsoft.Network/networkInterfaces', concat(nicNamePrefix, i))
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: storageAccountName.properties.primaryEndpoints.blob
      }
    }
  }
  dependsOn: [
    nicNamePrefix_resource
  ]
}]

resource vnetName_resource 'Microsoft.Network/virtualNetworks@2020-11-01' = {
  name: vnetName
  location: resourceGroup().location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: subnet0Name
        properties: {
          addressPrefix: '10.0.1.0/24'
          networkSecurityGroup: {
            id: webNetworkSecurityGroupName.id
          }
        }
      }
    ]
  }
}

resource pipName_resource 'Microsoft.Network/publicIPAddresses@2020-11-01' = [for i in range(0, vmCount): {
  name: concat(pipName, i)
  location: resourceGroup().location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
  }
}]

resource storageAccountName 'Microsoft.Storage/storageAccounts@2019-06-01' = {
  name: storageAccountName_var
  location: resourceGroup().location
  sku: {
    name: storageAccountType
  }
  kind: 'Storage'
  properties: {}
}

resource webNetworkSecurityGroupName 'Microsoft.Network/networkSecurityGroups@2020-11-01' = {
  name: webNetworkSecurityGroupName_var
  location: resourceGroup().location
  properties: {
    securityRules: [
      {
        name: 'custom-allow-ssh'
        properties: {
          priority: 1000
          sourceAddressPrefix: '*'
          protocol: '*'
          destinationPortRange: '22'
          access: 'Allow'
          direction: 'Inbound'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}
