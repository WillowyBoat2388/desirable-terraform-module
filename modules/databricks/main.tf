resource "random_string" "cluster_name" {
  length  = 13
  lower   = true
  numeric = false
  special = false
  upper   = false

  keepers = {
    constant = data.azurerm_resource_group.rg.id
  }

}

data "azurerm_user_assigned_identity" "identity" {
  name                = var.environmentid_name
  resource_group_name = var.parent
}

data "azurerm_key_vault" "vault" {
  name                = var.key_vault
  resource_group_name = var.rg_name
}

data "azurerm_resource_group" "rg" {
  name = var.rg_name
}

data "azurerm_databricks_workspace" "workspace" {
  name                = var.workspace_name
  resource_group_name = var.rg_name
}

# Use the latest Databricks Runtime
# Long Term Support (LTS) version.
data "databricks_spark_version" "latest_lts" {

  long_term_support = true

  depends_on = [data.azurerm_databricks_workspace.workspace]
}

# Create the cluster with the "smallest" amount
# of resources allowed.
data "databricks_node_type" "smallest" {
  # category   = "Memory Optimized"
  # local_disk = true
  provider_config {
    workspace_id = data.azurerm_databricks_workspace.workspace.workspace_id
  }
  depends_on = [data.databricks_spark_version.latest_lts]
}

data "databricks_catalog" "this" {
  name = local.catalog_name
}

data "databricks_current_metastore" "this" {

  depends_on = [data.databricks_spark_version.latest_lts]
}


data "databricks_group" "admins" {
  display_name = "admins"

  depends_on = [data.databricks_spark_version.latest_lts]
}

# locals {
#   current_user_id = coalesce(var.msi_id, data.azurerm_client_config.current.object_id)
# }



resource "databricks_group" "eng" {

  display_name = "Data Engineering"
  depends_on   = [data.azurerm_databricks_workspace.workspace, data.databricks_spark_version.latest_lts]
}

resource "databricks_group_member" "eng" {

  group_id  = databricks_group.eng.id
  member_id = data.databricks_group.admins.id


  depends_on = [data.databricks_group.admins, databricks_group.eng]
}


resource "databricks_storage_credential" "ong_cred" {
  name = "ong_storage_cred"

  # purpose = "SERVICE"
  comment = "Managed identity storage credential managed by TF"
  azure_managed_identity {
    managed_identity_id = data.azurerm_user_assigned_identity.identity.id
    access_connector_id = var.service_connector
  }

  force_destroy = true

  lifecycle {
    create_before_destroy = true
  }
}

resource "databricks_secret_scope" "kv" {
  name = "databricks-keyvault"

  keyvault_metadata {
    resource_id = data.azurerm_key_vault.vault.id
    dns_name    = data.azurerm_key_vault.vault.vault_uri
  }

}


resource "databricks_external_location" "ong_data_stream" {
  name            = "analytics_data_stream"
  url             = local.external
  credential_name = databricks_storage_credential.ong_cred.id
  comment         = "Managed by TF"
  depends_on = [
    data.databricks_current_metastore.this, databricks_storage_credential.ong_cred
  ]

  # force_destroy = true
  lifecycle {
    create_before_destroy = true
  }
}

resource "databricks_volume" "sensorstream" {
  name             = "ong_sensorstream"
  catalog_name     = data.databricks_catalog.this.name
  schema_name      = "default"
  volume_type      = "EXTERNAL"
  storage_location = "${local.external}/analytics"
  comment          = "this volume is managed by terraform"

  depends_on       = [databricks_external_location.ong_data_stream]
}

resource "databricks_volume" "checkPoints" {
  name         = "checkpoints"
  catalog_name = data.databricks_catalog.this.name
  schema_name  = "default"
  volume_type  = "MANAGED"
  comment      = "this volume is managed by terraform"
}

resource "databricks_schema" "bronze_layer" {
  name         = "landing"
  catalog_name = data.databricks_catalog.this.name
  properties = {
    kind = "various"
  }
  comment = "this schema is managed by terraform"
}

resource "databricks_schema" "bronze_layer2" {
  name         = "raw"
  catalog_name = data.databricks_catalog.this.name
  properties = {
    kind = "various"
  }
  comment = "this schema is managed by terraform"
}

resource "databricks_schema" "silver" {
  name         = "base"
  catalog_name = data.databricks_catalog.this.name
  properties = {
    kind = "various"
  }
  comment = "this volume is managed by terraform"
}

resource "databricks_schema" "gold" {
  name         = "serving"
  catalog_name = data.databricks_catalog.this.name
  properties = {
    kind = "various"
  }
  comment = "this schema is managed by terraform"
}




resource "databricks_instance_pool" "smallest_nodes" {
  instance_pool_name = "Smallest Nodes"
  min_idle_instances = 5
  max_capacity       = 25
  node_type_id       = data.databricks_node_type.smallest.id
  azure_attributes {
    availability           = "ON_DEMAND_AZURE"
    spot_bid_max_price = "-1"
  }
  idle_instance_autotermination_minutes = 30
  # custom_tags = local.tags
  enable_elastic_disk = true
  preloaded_spark_versions = [ data.databricks_spark_version.latest_lts.id]
  depends_on = [data.databricks_spark_version.latest_lts]
}

resource "databricks_git_credential" "workspacejobs-source" {
  git_username          = var.github_username
  git_email             = var.github_email
  git_provider          = "gitHub"
  personal_access_token = var.github_pat

  lifecycle {
    ignore_changes = [ personal_access_token ]
  }

}


resource "databricks_repo" "git_integration" {
  url          = var.jobsource_url
  path         = "${local.repo_source}/"
  depends_on   =  [resource.databricks_git_credential.workspacejobs-source]

  lifecycle {
    ignore_changes = [ path ]
  }

}

resource "databricks_notification_destination" "slack" {
  display_name = "Slack Notification Destination"
  config {
    slack {
      url = var.slack_key
    }
  }

  lifecycle {
    ignore_changes = [ config ]
  }

}

data "databricks_sql_warehouses" "all" {
}
  
resource "databricks_job" "dashboard_push" {
  name        = "well-telemetry-dashboard-push"
  description = "This job executes multiple tasks on a shared job cluster, which will be provisioned as part of execution, and terminated once all tasks are finished."
  run_as {
    service_principal_name = data.azurerm_user_assigned_identity.identity.client_id
  }

  job_cluster { 
    job_cluster_key = "dashboard_cluster"
    new_cluster {
      instance_pool_id            = databricks_instance_pool.smallest_nodes.id
      spark_version           = data.databricks_spark_version.latest_lts.id
      data_security_mode      = var.cluster_data_security_mode

    }
  }

  trigger {
    table_update {
      table_names = ["${local.catalog_name}.raw.well-telemetry"]
      condition = "ALL_UPDATED"
    }
  }

  task {
    task_key = "silver_layer_lease_fill"

    job_cluster_key = "dashboard_cluster"
    max_retries = 1

    spark_python_task {
      python_file = "${local.repo_source}/silver_layer_transform/base_lease_refresh.py"
    }
  }
  
  task {
    task_key = "silver_layer_firm_fill"

    
    new_cluster {
      enable_local_disk_encryption = true
      spark_version = data.databricks_spark_version.latest_lts.id
      instance_pool_id  = databricks_instance_pool.smallest_nodes.id
      autoscale {
        min_workers = 1
        max_workers = 25
      }
      spark_conf = {
        "spark.databricks.io.cache.enabled" : true,
        "spark.databricks.io.cache.maxDiskUsage" : "500g",
        "spark.databricks.io.cache.maxMetaDataCache" : "10g"
      }
    }
    max_retries = 1

    spark_python_task {
      python_file = "${local.repo_source}/silver_layer_transform/base_firm_refresh.py"
    }  
  }
  
  task {
    task_key = "gold_layer_transform_iteration"
    max_retries = 1
    depends_on {
      task_key = "silver_layer_lease_fill"
    }

    sql_task {
      warehouse_id = tolist(data.databricks_sql_warehouses.all.ids)[0]
      file {
        source   = "WORKSPACE"
        path = "${local.repo_source}/gold_bi_table_sink/serving_fill.sql"
      }
    }  
  }


  email_notifications {
    on_failure                             = [var.github_email]
    on_duration_warning_threshold_exceeded = [var.github_email]
  }

  webhook_notifications {
    on_failure {
      id = databricks_notification_destination.slack.id
    }
    on_duration_warning_threshold_exceeded {
      id = databricks_notification_destination.slack.id
    }
  }

  health {
    rules {
      metric = "RUN_DURATION_SECONDS"
      op     = "GREATER_THAN"
      value  = 1020
    }
  }

  tags = local.tags


  edit_mode = "UI_LOCKED"


}



resource "databricks_job" "telemetry_stream" {
  name        = "well-telemetry-stream-pull"
  description = "This job executes multiple tasks on a shared job cluster, which will be provisioned as part of execution, and terminated once all tasks are finished."
  run_as {
    service_principal_name = data.azurerm_user_assigned_identity.identity.client_id
  }

  
  job_cluster { 
    job_cluster_key = "stream_ingest_cluster"
    new_cluster {
      instance_pool_id            = databricks_instance_pool.smallest_nodes.id
      spark_version           = data.databricks_spark_version.latest_lts.id
      data_security_mode      = var.cluster_data_security_mode

    }
  }

  schedule {
    timezone_id            = "UTC"
    quartz_cron_expression = "0 0/15 * * * ?"

  }

  parameter {
    name    = "source_list"
    default = <<EOF
        ["well-telemetry", "facility-telemetry", "equipment-events"]
  EOF

  }

  task {
    task_key = "data_stream_wrangle"


    for_each_task {
      concurrency = 2
      inputs      = "{{ job.parameters.source_list }}"
      task {
        task_key = "data_stream_wrangle_iteration"

        job_cluster_key = "stream_ingest_cluster"
        max_retries = 1

        spark_python_task {
          python_file = "${local.repo_source}/bronze_layer_ingest/ingestion_landing_zone.py"
          parameters  = ["{{input}}"]
        }
      }
    }
  }

  task {
    task_key = "rawzone_loading"
    //this task will only run after task a
    depends_on {
      task_key = "data_stream_wrangle"
    }

    for_each_task {
      concurrency = 3
      inputs      = "{{job.parameters.source_list}}"
      task {
        task_key = "rawzone_loading_iteration"

        job_cluster_key = "stream_ingest_cluster"
        max_retries = 1

        spark_python_task {
          python_file = "${local.repo_source}/bronze_layer_ingest/ingestion_raw_zone.py"
          parameters  = ["{{input}}"]
        }
      }
    }
  }

email_notifications {
    on_failure                             = [var.github_email]
    on_duration_warning_threshold_exceeded = [var.github_email]
  }

  webhook_notifications {
    on_failure {
      id = databricks_notification_destination.slack.id
    }
    on_duration_warning_threshold_exceeded {
      id = databricks_notification_destination.slack.id
    }
  }

  health {
    rules {
      metric = "RUN_DURATION_SECONDS"
      op     = "GREATER_THAN"
      value  = 1200
    }
  }

  tags = local.tags




  edit_mode = "UI_LOCKED"


}


resource "databricks_job" "bidaily_batch_pull" {
  name        = "bidaily-batch-pull"
  description = "This job executes multiple tasks on a shared job cluster, which will be provisioned as part of execution, and terminated once all tasks are finished."
  run_as {
    service_principal_name = data.azurerm_user_assigned_identity.identity.client_id
  }

  
  job_cluster { 
    job_cluster_key = "bidaily_cluster"
    new_cluster {
      instance_pool_id            = databricks_instance_pool.smallest_nodes.id
      spark_version           = data.databricks_spark_version.latest_lts.id
      data_security_mode      = var.cluster_data_security_mode

    }
  }

  trigger {
    periodic {
      interval = 12
      unit     = "HOURS"
    }
  }

  parameter {
    name    = "source_list"
    default = <<EOF
        ["reservoir", "wellbore"]
  EOF

  }

  task {
    task_key = "data_stream_wrangle"


    for_each_task {
      concurrency = 2
      inputs      = "{{job.parameters.source_list}}"
      task {
        task_key = "data_stream_wrangle_iteration"

        job_cluster_key = "bidaily_cluster"
        max_retries = 1

        spark_python_task {
          python_file = "${local.repo_source}/bronze_layer_ingest/ingestion_landing_zone.py"
          parameters  = ["{{input}}"]
        }
      }
    }
  }

  task {
    task_key = "rawzone_loading"
    //this task will only run after task a
    depends_on {
      task_key = "data_stream_wrangle"
    }

    for_each_task {
      concurrency = 2
      inputs      = "{{ job.parameters.source_list }}"
      task {
        task_key = "rawzone_loading_iteration"

        job_cluster_key = "bidaily_cluster"
        max_retries = 1

        spark_python_task {
          python_file = "${local.repo_source}/bronze_layer_ingest/ingestion_raw_zone.py"
          parameters  = ["{{input}}"]
        }
      }
    }
  }


  email_notifications {
    on_failure                             = ["onidajo99@gmail.com"]
    on_duration_warning_threshold_exceeded = ["onidajo99@gmail.com"]
  }

  webhook_notifications {
    on_failure {
      id = databricks_notification_destination.slack.id
    }
    on_duration_warning_threshold_exceeded {
      id = databricks_notification_destination.slack.id
    }
  }

  health {
    rules {
      metric = "RUN_DURATION_SECONDS"
      op     = "GREATER_THAN"
      value  = 1200
    }
  }

  tags = local.tags




  edit_mode = "UI_LOCKED"


}


resource "databricks_job" "daily_prod_pull" {
  name        = "daily-prod-pull"
  description = "This job pulls in from Kafka-sink to landing and raw zone."
  run_as {
    service_principal_name = data.azurerm_user_assigned_identity.identity.client_id
  }

  job_cluster {
    job_cluster_key = "daily_cluster"
    new_cluster {
      kind                    = "CLASSIC_PREVIEW"
      is_single_node          = true
      data_security_mode      = var.cluster_data_security_mode
      spark_version           = data.databricks_spark_version.latest_lts.id
      instance_pool_id        = databricks_instance_pool.smallest_nodes.id
    }
  }

  trigger {
    file_arrival {
      url = "${local.external}/analytics/output/production-daily-data/"
    }
  }


  task {
    task_key = "data_stream_wrangle"

  
    max_retries = 1
    job_cluster_key = "daily_cluster"

    spark_python_task {
      python_file = "${local.repo_source}/bronze_layer_ingest/ingestion_landing_zone.py"
      parameters  = ["production-daily-data"]
    }
  }

  task {
    task_key = "rawzone_loading"
    //this task will only run after task a
    depends_on {
      task_key = "data_stream_wrangle"
    }

    
    max_retries = 1
    job_cluster_key = "daily_cluster"

    spark_python_task {
      python_file = "${local.repo_source}/bronze_layer_ingest/ingestion_raw_zone.py"
      parameters  = ["production-daily-data"]
    }
  }

  email_notifications {
    on_failure                             = ["onidajo99@gmail.com"]
    on_duration_warning_threshold_exceeded = ["onidajo99@gmail.com"]
  }

  webhook_notifications {
    on_failure {
      id = databricks_notification_destination.slack.id
    }
    on_duration_warning_threshold_exceeded {
      id = databricks_notification_destination.slack.id
    }
  }

  health {
    rules {
      metric = "RUN_DURATION_SECONDS"
      op     = "GREATER_THAN"
      value  = 1200
    }
  }

  tags = local.tags




  edit_mode = "UI_LOCKED"


}


locals {
  tags = {
    Environment  = var.environment
    team         = var.team
    owner        = var.owner
    subscription = var.rg_parent_id
  }
  catalog_name = lower(replace(var.workspace_name, "-", "_"))

  repo_source = "/Shared/wellanalysisstream"
  external = format("abfss://%s@%s.dfs.core.windows.net",
    var.storage_container,
  var.storage_account)
}