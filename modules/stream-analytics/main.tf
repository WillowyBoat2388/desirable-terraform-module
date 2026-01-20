resource "azurerm_storage_account" "storage_account" {
  access_tier                     = "Hot"
  account_kind                    = "StorageV2"
  account_replication_type        = "RAGRS"
  account_tier                    = "Standard"
  allow_nested_items_to_be_public = true
  dns_endpoint_type               = "Standard"
  https_traffic_only_enabled      = true
  is_hns_enabled                  = true
  large_file_share_enabled        = true
  local_user_enabled              = true
  location                        = var.location
  min_tls_version                 = "TLS1_2"
  name                            = "analyticsstorage${random_integer.uid.result}"
  public_network_access_enabled   = true
  queue_encryption_key_type       = "Service"
  resource_group_name             = var.rg_name
  shared_access_key_enabled       = true
  table_encryption_key_type       = "Service"
  tags = {
    environment = var.environment
    team        = var.team
  }
  blob_properties {
    change_feed_enabled      = false
    default_service_version  = "2023-01-03"
    last_access_time_enabled = false
    versioning_enabled       = false
    container_delete_retention_policy {
      days = 7
    }
    delete_retention_policy {
      days                     = 7
      permanent_delete_enabled = false
    }
  }
  share_properties {
    retention_policy {
      days = 7
    }
  }
}


resource "azurerm_role_assignment" "storageAccountRoleAssignment" {
  scope                = azurerm_storage_account.storage_account.id
  role_definition_name = "Storage Account Contributor"
  principal_id         = var.identity_objid
}

resource "azurerm_role_assignment" "storageAccountRoleAssignment2" {
  scope                = azurerm_storage_account.storage_account.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = var.identity_objid
}

resource "azurerm_storage_data_lake_gen2_filesystem" "adls_gen2" {
  name               = "example"
  storage_account_id = azurerm_storage_account.storage_account.id
  ace {
    type        = "user"
    permissions = "rwx"
  }
  ace {
    type        = "user"
    id          = var.identity_id
    permissions = "--x"
  }
  ace {
    type        = "group"
    permissions = "r-x"
  }
  ace {
    type        = "mask"
    permissions = "r-x"
  }
  ace {
    type        = "other"
    permissions = "---"
  }
  depends_on = [
    azurerm_role_assignment.storageAccountRoleAssignment
  ]
}

resource "azurerm_storage_data_lake_gen2_path" "adls_gen2_path" {
  storage_account_id = azurerm_storage_account.storage_account.id
  filesystem_name    = azurerm_storage_data_lake_gen2_filesystem.adls_gen2.name
  path               = "storage"
  resource           = "directory"
  ace {
    type        = "user"
    permissions = "r-x"
  }
  ace {
    type        = "user"
    id          = var.identity_id
    permissions = "r-x"
  }
  ace {
    type        = "group"
    permissions = "-wx"
  }
  ace {
    type        = "mask"
    permissions = "--x"
  }
  ace {
    type        = "other"
    permissions = "--x"
  }
  ace {
    scope       = "default"
    type        = "user"
    permissions = "r-x"
  }
  ace {
    scope       = "default"
    type        = "user"
    id          = var.identity_id
    permissions = "r-x"
  }
  ace {
    scope       = "default"
    type        = "group"
    permissions = "-wx"
  }
  ace {
    scope       = "default"
    type        = "mask"
    permissions = "--x"
  }
  ace {
    scope       = "default"
    type        = "other"
    permissions = "--x"
  }
}


resource "azurerm_storage_container" "analytics_container" {
  name                  = "analyticscontainer"
  storage_account_id    = azurerm_storage_account.storage_account.id
  container_access_type = "blob"
}

resource "random_uuid" "roleass4" {
  keepers = {
    # Generate a new id each time we switch to a new AMI id
    ami_id = var.rg_id
  }

}

resource "random_uuid" "roleass2" {
  keepers = {
    # Generate a new id each time we switch to a new AMI id
    ami_id = var.rg_id
  }

}

resource "random_uuid" "roleass3" {
  keepers = {
    # Generate a new id each time we switch to a new AMI id
    ami_id = var.rg_id
  }

}


# Generate a random integer to create a globally unique name
resource "random_integer" "uid" {
  min = 10000
  max = 99999
}

resource "random_pet" "stream" {
  prefix = var.prefix
}

resource "azapi_resource" "eventhub_namespace" {
  body = {
    properties = {
      disableLocalAuth = false
      geoDataReplication = {
        locations = [{
          locationName = var.location
          roleType     = "Primary"
        }]
        maxReplicationLagDurationInSeconds = 0
      }
      isAutoInflateEnabled   = true
      kafkaEnabled           = true
      maximumThroughputUnits = 5
      minimumTlsVersion      = "1.2"
      platformCapabilities = {
        confidentialCompute = {
          mode = "Disabled"
        }
      }
      publicNetworkAccess = "Enabled"
      zoneRedundant       = true
    }
    sku = {
      capacity = 1
      name     = "Standard"
      tier     = "Standard"
    }
  }
  ignore_casing             = false
  ignore_missing_property   = true
  ignore_null_property      = false
  location                  = var.location
  name                      = random_pet.stream.id
  parent_id                 = var.rg_id
  schema_validation_enabled = true
  tags = {
    "Owner"       = var.owner
    id            = "bdn-ongupstream-log-${random_integer.uid.result}"
    "environment" = var.environment
    team          = var.team
  }
  type = "Microsoft.EventHub/namespaces@2025-05-01-preview"
  identity {
    identity_ids = []
    type         = "SystemAssigned"
  }
}

resource "azurerm_eventhub" "eventhub" {

  name            = "bdn-energy-data"
  namespace_id    = azapi_resource.eventhub_namespace.id
  partition_count = 7
  status          = "Active"
  capture_description {
    enabled             = false
    encoding            = "Avro"
    interval_in_seconds = 300
    size_limit_in_bytes = 314572800
    skip_empty_archives = true
    destination {
      archive_name_format = "{Namespace}/{EventHub}/{PartitionId}/{Year}/{Month}/{Day}/{Hour}/{Minute}/{Second}"
      blob_container_name = "upstream-stream"
      name                = "EventHubArchive.AzureBlockBlob"
      storage_account_id  = azurerm_storage_account.storage_account.id
    }
  }
  retention_description {
    cleanup_policy          = "Delete"
    retention_time_in_hours = 1
  }
}

resource "azapi_resource" "eventhub" {
  type                      = "Microsoft.EventHub/namespaces/eventhubs@2025-05-01-preview"
  ignore_casing             = false
  ignore_missing_property   = true
  ignore_null_property      = false
  name                      = "energy-stream"
  parent_id                 = azapi_resource.eventhub_namespace.id
  schema_validation_enabled = true
  body = {
    properties = {
      captureDescription = {
        destination = {
          name = "EventHubArchive.AzureBlockBlob"
          properties = {
            archiveNameFormat        = "{Namespace}/{EventHub}/{PartitionId}/{Year}/{Month}/{Day}/{Hour}/{Minute}/{Second}"
            blobContainer            = "upstream-stream"
            storageAccountResourceId = azurerm_storage_account.storage_account.id
          }
        }
        enabled           = false
        encoding          = "Avro"
        intervalInSeconds = 300
        sizeLimitInBytes  = 314572800
        skipEmptyArchives = true
      }
      messageRetentionInDays = 1
      messageTimestampDescription = {
        timestampType = "LogAppend"
      }
      partitionCount = 7
      retentionDescription = {
        cleanupPolicy        = "Delete"
        retentionTimeInHours = 1
      }
      status = "Active"
    }
  }
}

resource "azurerm_databricks_access_connector" "service_connector" {
  name                = "service_connector"
  resource_group_name = var.rg_name
  location            = var.location

  identity {
    type         = "UserAssigned"
    identity_ids = [var.identity_subid]
  }

  tags = local.tags
}

# data "azurerm_key_vault_key" "managed_key_vault" {}

# resource "azapi_resource" "containerapps1" {
#   body = {
#     kind = "containerapps"
#     properties = {
#       configuration = {
#         activeRevisionsMode = "Single"
#         dapr                = null
#         identitySettings    = []
#         ingress = {
#           additionalPortMappings = null
#           allowInsecure          = false
#           clientCertificateMode  = "Ignore"
#           corsPolicy             = null
#           customDomains = [{
#             bindingType   = "SniEnabled"
#             certificateId = "/subscriptions/3454637f-16bd-4c6c-97c2-af2012e3adaf/resourceGroups/bdnappinsights/providers/Microsoft.App/managedEnvironments/bdnappinsights/managedCertificates/bdatanet.tech-bdnappin-250923125157"
#             name          = "bdatanet.tech"
#           }]
#           exposedPort            = 0
#           external               = true
#           ipSecurityRestrictions = null
#           stickySessions = {
#             affinity = "sticky"
#           }
#           targetPort           = 8002
#           targetPortHttpScheme = null
#           traffic = [{
#             latestRevision = true
#             weight         = 100
#           }]
#           transport = "Auto"
#         }
#        maxInactiveRevisions = 100
#         registries = [{
#           identity          = ""
#           passwordSecretRef = "bdnappinsightsregistryazurecrio-bdnappinsightsregistry"
#          server            = "bdnappinsightsregistry.azurecr.io"
#           username          = "bdnappinsightsregistry"
#         }]
#         revisionTransitionThreshold = null
#         runtime                     = null
#         secrets = [{
#           name = "bdnappinsightsregistryazurecrio-bdnappinsightsregistry"
#         }]
#         service     = null
#         targetLabel = ""
#       }
#       environmentId        = azapi_resource.res-3.id
#       managedEnvironmentId = azapi_resource.res-3.id
#       template = {
#         containers = [{
#           env = [{
#             name  = "DATABASE_URI"
#             value = "postgresql+psycopg://neondb_owner:npg_YH2Ne9rXBjVA@ep-rapid-king-a9crvxhh-pooler.gwc.azure.neon.tech/bdn_site?sslmode=require&channel_binding=require"
#             }, {
#             name  = "PRIVATE_KEY"
#             value = "superset"
#             }, {
#             name  = "motherduck_token"
#             value = "superset_token"
#             }, {
#             name  = "PORT"
#             value = "unnecessary"
#             }, {
#             name  = "KEY_ID"
#             value = "unnecessary"
#           }]
#           image     = "bdnappinsightsregistry.azurecr.io/bdn-site:889b3f6f2459bf6c343aa5978d2771330482beff"
#           imageType = "ContainerImage"
#           name      = "site-deployment-cont"
#           probes    = []
#           resources = {
#             cpu    = 0.5
#             memory = "1Gi"
#           }
#         }]
#         initContainers = null
#         revisionSuffix = ""
#         scale = {
#           cooldownPeriod  = 300
#           maxReplicas     = 10
#           minReplicas     = 0
#           pollingInterval = 30
#           rules           = null
#         }
#         serviceBinds                  = null
#         terminationGracePeriodSeconds = null
#         volumes                       = []
#       }
#       workloadProfileName = "Consumption"
#     }
#   }
#   ignore_casing             = false
#   ignore_missing_property   = true
#   ignore_null_property      = false
#   location                  = "southafricanorth"
#   name                      = "bdn-site"
#   parent_id                 = azurerm_resource_group.environment.id
#   schema_validation_enabled = true
#   tags = {
#     environment = var.environment
#     owner       = var.owner
#     team        = var.team
#   }
#   type = "Microsoft.App/containerApps@2025-02-02-preview"
#   identity {
#     identity_ids = []
#     type         = "None"
#   }
# }

data "azapi_resource_id" "workspace_resource_group" {
  type      = "Microsoft.Resources/resourceGroups@2020-06-01"
  parent_id = var.rg_parent_id
  name      = "databricks-rg-processingWorkspace"

}

resource "azapi_resource" "workspace" { #"analytics_workspace" {
  type      = "Microsoft.Databricks/workspaces@2025-10-01-preview"
  parent_id = var.rg_id
  name      = "processingWorkspace"
  location  = var.location
  tags = {
    "Owner"       = var.owner
    id            = "processingWorkspace-${random_integer.uid.result}"
    "environment" = var.environment
    team          = var.team
  }
  body = {
    properties = {
      managedResourceGroupId = data.azapi_resource_id.workspace_resource_group.id
      parameters = {
        prepareEncryption = {
          value = true
        }
        requireInfrastructureEncryption = {
          value = true
        }
      }
      publicNetworkAccess = "Enabled"
      computeMode         = "Hybrid"
    }
    sku = {
      name = "premium"
    }

  }
  schema_validation_enabled = true
  response_export_values    = ["*"]
}

#       parameters = {

#         customPrivateSubnetName = {
#           type = "string"
#           value = "string"
#         }
#         customPublicSubnetName = {
#           type = "string"
#           value = "string"
#         }
#         customVirtualNetworkId = {
#           type = "string"
#           value = "string"
#         }
#         enableNoPublicIp = {
#           type = "string"
#           value = bool
#         }
#         encryption = {
#           type = "string"
#           value = {
#             KeyName = "string"
#             keySource = "string"
#             keyvaulturi = "string"
#             keyversion = "string"
#           }
#         }
#         loadBalancerBackendPoolName = {
#           type = "string"
#           value = "string"
#         }
#         loadBalancerId = {
#           type = "string"
#           value = "string"
#         }
#         natGatewayName = {
#           type = "string"
#           value = "string"
#         }
#         prepareEncryption = {
#           type = "string"
#           value = bool
#         }
#         publicIpName = {
#           type = "string"
#           value = "string"
#         }
#         vnetAddressPrefix = {
#           type = "string"
#           value = "string"
#         }
#       }
#       publicNetworkAccess = "string"
#       requiredNsgRules = "string"
#     }
#   }
# }


data "azurerm_role_definition" "roleDataOwner" {
  name  = "Storage Blob Data Owner"
  scope = azurerm_storage_container.analytics_container.id

  depends_on = [azurerm_storage_container.analytics_container]
}


resource "azapi_resource" "roleAssignment4" {
  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  name      = random_uuid.roleass4.result
  parent_id = azurerm_storage_container.analytics_container.id
  body = {
    properties = {
      principalId      = var.identity_objid
      principalType    = "ServicePrincipal"
      roleDefinitionId = data.azurerm_role_definition.roleDataOwner.id
    }
  }

  depends_on = [azurerm_storage_container.analytics_container]
}


data "azurerm_role_definition" "roleConnectorContributor" {
  name  = "Service Connector Contributor"
  scope = azurerm_storage_account.storage_account.id

  depends_on = [azurerm_storage_account.storage_account]
}


resource "azapi_resource" "roleAssignment3" {
  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  name      = random_uuid.roleass3.result
  parent_id = azurerm_storage_account.storage_account.id
  body = {
    properties = {
      principalId      = var.identity_objid
      principalType    = "ServicePrincipal"
      roleDefinitionId = data.azurerm_role_definition.roleConnectorContributor.id
    }
  }

  depends_on = [azurerm_storage_account.storage_account]
}



data "azurerm_role_definition" "roleContributor" {
  name  = "Contributor"
  scope = var.rg_id

  depends_on = [azapi_resource.workspace]
}


resource "azapi_resource" "roleAssignment2" {
  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  name      = random_uuid.roleass2.result
  parent_id = var.rg_id
  body = {
    properties = {
      principalId      = var.identity_objid
      principalType    = "ServicePrincipal"
      roleDefinitionId = data.azurerm_role_definition.roleContributor.id
    }
  }

  depends_on = [azapi_resource.workspace]
}

locals {
  tags = {
    Environment  = var.environment
    team         = var.team
    owner        = var.owner
    subscription = var.rg_parent_id
  }

}

output "databricks_service_connector" {
  value = azurerm_databricks_access_connector.service_connector.id

}

output "databricks_workspace_url" {
  value = azapi_resource.workspace.output.properties.workspaceUrl
}

output "databricks_workspace_id" {
  value = azapi_resource.workspace.output.properties.workspaceId
}

output "databricks_workspace_resource_id" {
  value = azapi_resource.workspace.id
}


