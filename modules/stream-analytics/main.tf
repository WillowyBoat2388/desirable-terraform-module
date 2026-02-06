
data "azurerm_key_vault" "vault" {
  name                = var.key_vault
  resource_group_name = var.rg_name
}

data "azurerm_user_assigned_identity" "environmentid" {
  name                = var.environmentid_name
  resource_group_name = var.parent
}

locals {
  tags = {
    Environment  = var.environment
    team         = var.team
    owner        = var.owner
    subscription = var.rg_parent_id
  }
  identity_objid = data.azurerm_user_assigned_identity.environmentid.principal_id
  identity_subid = data.azurerm_user_assigned_identity.environmentid.id
}

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
  name                            = "analyticsstorage${var.random_integer}"
  public_network_access_enabled   = true
  queue_encryption_key_type       = "Service"
  resource_group_name             = var.rg_name
  shared_access_key_enabled       = true
  table_encryption_key_type       = "Service"
  tags                            = local.tags
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
  principal_id         = local.identity_objid
}

resource "azurerm_role_assignment" "storageAccountRoleAssignment2" {
  scope                = azurerm_storage_account.storage_account.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = local.identity_objid
}

data "azurerm_resource_group" "resourceGroup" {

  name = var.rg_name
}

resource "azurerm_storage_container" "analytics_container" {
  name                  = "analyticscontainer"
  storage_account_id    = azurerm_storage_account.storage_account.id
  container_access_type = "blob"
}

resource "azurerm_storage_container" "events_container" {
  name                  = "upstream-stream"
  storage_account_id    = azurerm_storage_account.storage_account.id
  container_access_type = "blob"
}

resource "random_uuid" "roleass4" {
  keepers = {
    # Generate a new id each time we switch to a new AMI id
    ami_id = var.rg_name
  }

}

resource "random_uuid" "roleass6" {
  keepers = {
    # Generate a new id each time we switch to a new AMI id
    ami_id = var.rg_name
  }

}

resource "random_uuid" "roleass5" {
  keepers = {
    # Generate a new id each time we switch to a new AMI id
    ami_id = var.rg_name
  }

}

resource "random_uuid" "roleass2" {
  keepers = {
    # Generate a new id each time we switch to a new AMI id
    ami_id = var.rg_name
  }

}

resource "random_uuid" "roleass3" {
  keepers = {
    # Generate a new id each time we switch to a new AMI id
    ami_id = var.rg_name
  }

}


resource "random_pet" "stream" {
  prefix = var.prefix

  keepers = {
    constant = var.rg_name
  }


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
  parent_id                 = data.azurerm_resource_group.resourceGroup.id
  schema_validation_enabled = true
  tags = {
    "Owner"       = var.owner
    id            = "bdn-ongupstream-log-${var.random_integer}"
    "environment" = var.environment
    team          = var.team
  }
  type = "Microsoft.EventHub/namespaces@2025-05-01-preview"
  identity {
    identity_ids = []
    type         = "SystemAssigned"
  }

  lifecycle {
    ignore_changes = [body.properties.geoDataReplication.locationName]
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
  depends_on = [azurerm_role_assignment.storageAccountRoleAssignment2, azapi_resource.roleAssignment4]

}

resource "azurerm_databricks_access_connector" "service_connector" {
  name                = "service_connector"
  resource_group_name = var.rg_name
  location            = var.location

  identity {
    type         = "UserAssigned"
    identity_ids = [local.identity_subid]
  }

  tags = local.tags
}

# data "azurerm_key_vault_key" "managed_key_vault" {}


data "azapi_resource_id" "workspace_resource_group" {
  type      = "Microsoft.Resources/resourceGroups@2025-04-01"
  parent_id = var.rg_parent_id
  name      = "databricks-ongrg-processingWorkspace"

}

resource "azapi_resource" "workspace" { #"analytics_workspace" {
  type      = "Microsoft.Databricks/workspaces@2025-10-01-preview"
  parent_id = data.azurerm_resource_group.resourceGroup.id
  name      = "ong_streamWorkspace-${var.random_integer}"
  location  = var.location
  tags = {
    "Owner"       = var.owner
    id            = "processingWorkspace-${var.random_integer}"
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
      principalId      = local.identity_objid
      principalType    = "ServicePrincipal"
      roleDefinitionId = data.azurerm_role_definition.roleDataOwner.id
    }
  }
  lifecycle {
    ignore_changes = [name]
  }

  depends_on = [azurerm_storage_container.analytics_container]
}


data "azurerm_role_definition" "roleQueueContributor" {
  name  = "Storage Queue Data Contributor"
  scope = azurerm_storage_account.storage_account.id

  depends_on = [azurerm_storage_account.storage_account]
}


resource "azapi_resource" "roleAssignment5" {
  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  name      = random_uuid.roleass5.result
  parent_id = azurerm_storage_container.analytics_container.id
  body = {
    properties = {
      principalId      = local.identity_objid
      principalType    = "ServicePrincipal"
      roleDefinitionId = data.azurerm_role_definition.roleQueueContributor.id
    }
  }
  lifecycle {
    ignore_changes = [name]
  }

  depends_on = [azurerm_storage_container.analytics_container]
}


data "azurerm_role_definition" "roleEventContributor" {
  name  = "EventGrid EventSubscription Contributor"
  scope = data.azurerm_resource_group.resourceGroup.id

  depends_on = [azapi_resource.workspace]
}


resource "azapi_resource" "roleAssignment6" {
  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  name      = random_uuid.roleass6.result
  parent_id = data.azurerm_resource_group.resourceGroup.id
  body = {
    properties = {
      principalId      = local.identity_objid
      principalType    = "ServicePrincipal"
      roleDefinitionId = data.azurerm_role_definition.roleEventContributor.id
    }
  }
  lifecycle {
    ignore_changes = [name]
  }

  depends_on = [azapi_resource.workspace]
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
      principalId      = local.identity_objid
      principalType    = "ServicePrincipal"
      roleDefinitionId = data.azurerm_role_definition.roleConnectorContributor.id
    }
  }
  lifecycle {
    ignore_changes = [name]
  }
  depends_on = [azurerm_storage_account.storage_account]
}



data "azurerm_role_definition" "roleContributor" {
  name  = "Contributor"
  scope = data.azurerm_resource_group.resourceGroup.id
}


resource "azapi_resource" "roleAssignment2" {
  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  name      = random_uuid.roleass2.result
  parent_id = data.azurerm_resource_group.resourceGroup.id
  body = {
    properties = {
      principalId      = local.identity_objid
      principalType    = "ServicePrincipal"
      roleDefinitionId = data.azurerm_role_definition.roleContributor.id
    }
  }
  lifecycle {
    ignore_changes = [name]
  }

}

output "storage_account_name" {
  value = azurerm_storage_account.storage_account.name

}

output "storage_container_name" {
  value = azurerm_storage_container.analytics_container.name

}

output "databricks_service_connector" {
  value = azurerm_databricks_access_connector.service_connector.id

}

# ephemeral "azurerm_key_vault_secret" "example" {
#   name         = "secret-sauce"
#   key_vault_id = data.azurerm_key_vault.example.id
# }

resource "azurerm_key_vault_secret" "databricks_workspace_url" {
  name         = "databricks-workspace-url"
  value        = azapi_resource.workspace.output.properties.workspaceUrl
  key_vault_id = data.azurerm_key_vault.vault.id
}

resource "azurerm_key_vault_secret" "databricks_workspace_id" {
  name         = "databricks-workspace-id"
  value        = azapi_resource.workspace.output.properties.workspaceId
  key_vault_id = data.azurerm_key_vault.vault.id
}

resource "azurerm_key_vault_secret" "databricks_workspace_resource_id" {
  name         = "databricks-workspace-resource-id"
  value        = azapi_resource.workspace.id
  key_vault_id = data.azurerm_key_vault.vault.id
}

resource "azurerm_key_vault_secret" "databricks_workspace_name" {
  name         = "databricks-workspace-name"
  value        = azapi_resource.workspace.name
  key_vault_id = data.azurerm_key_vault.vault.id
}

output "databricks_workspace_name" {
  value = azapi_resource.workspace.name

}



