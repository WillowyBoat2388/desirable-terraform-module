resource "random_string" "cluster_name" {
  length  = 13
  lower   = true
  numeric = false
  special = false
  upper   = false

  keepers = {
    constant = var.rg_id
  }

}

# Use the latest Databricks Runtime
# Long Term Support (LTS) version.
data "databricks_spark_version" "latest_lts" {

  long_term_support = true
  # provider          = databricks.workspace
  depends_on = [var.workspace_id, var.workspace_url]
}

# Create the cluster with the "smallest" amount
# of resources allowed.
data "databricks_node_type" "smallest" {
  # provider   = databricks.workspace
  local_disk = true
  provider_config {
    workspace_id = var.workspace_id
  }
  depends_on = [data.databricks_spark_version.latest_lts]
}

data "databricks_current_metastore" "this" {
  # provider   = databricks.workspace
  depends_on = [data.databricks_spark_version.latest_lts]
}


data "databricks_group" "admins" {
  display_name = "admins"
  # provider     = databricks.workspace
  depends_on = [data.databricks_spark_version.latest_lts]
}

# locals {
#   current_user_id = coalesce(var.msi_id, data.azurerm_client_config.current.object_id)
# }



resource "databricks_group" "eng" {
  # provider     = databricks.workspace
  display_name = "Data Engineering"
  depends_on   = [var.workspace_id, data.databricks_spark_version.latest_lts]
}

resource "databricks_group_member" "eng" {
  # provider   = databricks.workspace
  group_id   = databricks_group.eng.id
  member_id  = data.databricks_group.admins.id
  depends_on = [data.databricks_group.admins, databricks_group.eng]
}



# # assign account_admin role
# resource "databricks_service_principal_role" "this" {
#   # provider             = databricks.workspace
#   service_principal_id = databricks_service_principal.this.id
#   role                 = "account_admin"
# }

# resource "databricks_group_role" "eng_account_admin" {
#   # provider = databricks.account
#   group_id = databricks_group.eng.id
#   role     = "metastore_admin"
#   depends_on = [data.databricks_group.admins, databricks_group.eng]
# }

# resource "databricks_grant" "sandbox_data_engineers" {
# provider = databricks.workspace
# metastore = data.databricks_current_metastore.this.id

# principal  = data.databricks_group.admins.id
# privileges = ["CREATE_CATALOG", "CREATE_EXTERNAL_LOCATION", "CREATE_SERVICE_CREDENTIAL"]
# }

resource "databricks_storage_credential" "external_mi" {
  # provider = databricks.workspace
  name = "mi_credential"

  # purpose = "SERVICE"
  comment = "Managed identity credential managed by TF"
  azure_managed_identity {
    managed_identity_id = var.identity_subid
    access_connector_id = var.service_connector
  }
}


resource "databricks_external_location" "some" {
  name = "external"
  url = format("abfss://%s@%s.dfs.core.windows.net",
    var.storage_container,
  var.storage_account)
  credential_name = databricks_storage_credential.external_mi.id
  comment         = "Managed by TF"
  depends_on = [
    data.databricks_current_metastore.this
  ]
}

resource "databricks_cluster" "cluster" {
  # provider                = databricks.workspace
  cluster_name            = random_string.cluster_name.result
  kind                    = "CLASSIC_PREVIEW"
  is_single_node          = true
  node_type_id            = data.databricks_node_type.smallest.id
  spark_version           = data.databricks_spark_version.latest_lts.id
  autotermination_minutes = var.cluster_autotermination_minutes
  num_workers             = var.cluster_num_workers
  data_security_mode      = var.cluster_data_security_mode
  # single_user_name        = databricks_group.eng.display_name
  depends_on = [data.databricks_spark_version.latest_lts]

}

resource "databricks_permissions" "cluster_manage" {
  # provider   = databricks.workspace
  cluster_id = databricks_cluster.cluster.id

  access_control {
    group_name       = databricks_group.eng.display_name
    permission_level = "CAN_MANAGE"
  }
}

resource "databricks_grant" "external_creds" {
  storage_credential = databricks_storage_credential.external_mi.id

  principal  = databricks_group.eng.display_name
  privileges = ["CREATE_EXTERNAL_TABLE"]
}

resource "databricks_grants" "some" {
  external_location = databricks_external_location.some.id
  grant {
    principal  = databricks_group.eng.display_name
    privileges = ["BROWSE", "WRITE_FILES", "READ_FILES", "MANAGE"]
  }
}

locals {
  tags = {
    Environment  = var.environment
    team         = var.team
    owner        = var.owner
    subscription = var.rg_parent_id
  }

}


output "cluster_url" {
  value = databricks_cluster.cluster.url
}