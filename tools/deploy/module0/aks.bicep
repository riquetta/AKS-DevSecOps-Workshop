// mandatory params
@description('The unique DNS prefix for your cluster, such as myakscluster. This cannot be updated once the Managed Cluster has been created.')
param dnsPrefix string = resourceGroup().name // name is obtained from env

@description('The unique name for the AKS cluster, such as myAKSCluster.')
param clusterName string = 'devsecops-aks'

@description('The unique name for the Azure Key Vault.')
param akvName string = 'akv-${uniqueString(resourceGroup().id)}'


// Optional params
@description('The region to deploy the cluster. By default this will use the same region as the resource group.')
param location string = resourceGroup().location

@minValue(1)
@maxValue(50)
@description('Number of agents (VMs) to host docker containers. Allowed values must be in the range of 0 to 1000 (inclusive) for user pools and in the range of 1 to 1000 (inclusive) for system pools. The default value is 1.')
param agentCount int = 3

@description('VM size availability varies by region. If a node contains insufficient compute resources (memory, cpu, etc) pods might fail to run correctly. For more details on restricted VM sizes, see: https://docs.microsoft.com/azure/aks/quotas-skus-regions')
param agentVMSize string = 'Standard_DS2_v2'

// create azure container registry
resource acr 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = {
  name: 'acr${uniqueString(resourceGroup().id)}'
  location: location
  sku: {
    name: 'Standard'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    adminUserEnabled: true
  }
}

resource aks 'Microsoft.ContainerService/managedClusters@2022-09-02-preview' = {
  name: clusterName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    dnsPrefix: dnsPrefix
    agentPoolProfiles: [
      {
        name: 'agentpool'
        count: agentCount
        vmSize: agentVMSize
        osType: 'Linux'
        mode: 'System'
      }
    ]    
    aadProfile: {
      managed: true
      enableAzureRBAC: true
    }    
    // Inside Cluster Definition; add the following to properties

    addonProfiles: {
      omsAgent: {
        enabled: true
        config: {
            logAnalyticsWorkspaceResourceID: workspace.id
        }
    }

    // ...
}
  }
}

resource akv 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: akvName
  location: location
  properties: {
    sku: {
      name: 'standard'
      family: 'A'
    }
    tenantId: subscription().tenantId
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: aks.identity.principalId
        permissions: {
          keys: [
            'get'
          ]
          secrets: [
            'get'
          ]
        }
      }
    ]
  }
}


// Parameters...

@description('Log Analytics Workspace name')
param workspaceName string

// Log Analytics Workspace Definition 
resource workspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: workspaceName
  location: location
}

// Cluster Definition...

resource diag01 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
    name: 'diag01'
    scope: aks
    properties: {
        logs: [{
            category: 'cluster-autoscaler'
            enabled: true
            retentionPolicy: {
                days: 0
                enabled: false
            }
        }, {
            category: 'guard'
            enabled: true
            retentionPolicy: {
                days: 0
                enabled: false
            }
        }, {
            category: 'kube-apiserver'
            enabled: true
            retentionPolicy: {
                days: 0
                enabled: false
            }
        },{
            category: 'kube-audit'
            enabled: true
            retentionPolicy: {
                days: 0
                enabled: false
            } 
        }, {
            category: 'kube-audit-admin'
            enabled: true
            retentionPolicy: {
                days: 0
                enabled: false
            }
        }, {
            category: 'kube-controller-manager'
            enabled: true
            retentionPolicy: {
                days: 0
                enabled: false
            }
        }, {
            category: 'kube-scheduler'
            enabled: true
            retentionPolicy: {
                days: 0
                enabled: false
            }
        }]
        workspaceId: workspace.id
    }
}


output controlPlaneFQDN string = aks.properties.fqdn
