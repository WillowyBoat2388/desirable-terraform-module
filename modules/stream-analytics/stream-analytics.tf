
resource "random_pet" "stream_analytics_job_name" {
  prefix = var.prefix

  keepers = {
    constant = data.azurerm_resource_group.resourceGroup.id
  }


}

resource "azurerm_stream_analytics_job" "job" {
  name                                     = random_pet.stream_analytics_job_name.id
  resource_group_name                      = var.rg_name
  location                                 = var.location
  streaming_units                          = var.number_of_streaming_units
  events_out_of_order_max_delay_in_seconds = 0
  events_late_arrival_max_delay_in_seconds = 5
  data_locale                              = "en-US"
  events_out_of_order_policy               = "Adjust"
  output_error_policy                      = "Stop"

  transformation_query = <<QUERY
WITH individualContext AS (
    SELECT
        data,
        LEFT(partition_key, CHARINDEX('-', partition_key)-1) AS TGOD,
        PartitionId
    FROM 
        [eventhub-stream-input]
    PARTITION BY  PartitionId
),
advancedContext AS (
    SELECT 
        data,
        CASE
            WHEN TGOD = 'facility' THEN 'facility-telemetry'
            WHEN TGOD = 'equipment' THEN 'equipment-events'
            WHEN TGOD = 'well' THEN 'well-telemetry'
            WHEN TGOD = 'production' THEN 'production-daily-data'
            WHEN TGOD = 'reservoir' THEN 'reservoir'
            WHEN TGOD = 'wellbore' THEN 'wellbore'
            ELSE 'recovered'
        END AS partition_identity
    FROM
        individualContext
    PARTITION BY  PartitionId
)

SELECT stream.data.*, stream.partition_identity
INTO
    [output-to-blob-storage]
FROM advancedContext as stream
PARTITION BY PartitionId

QUERY

}


data "azurerm_eventhub_namespace" "eventhub_namespaces" {
  name                = azapi_resource.eventhub_namespace.name
  resource_group_name = var.rg_name
}


resource "azurerm_stream_analytics_stream_input_eventhub_v2" "job_input" {
  name                      = "eventhub-stream-input"
  stream_analytics_job_id   = azurerm_stream_analytics_job.job.id
  eventhub_name             = azapi_resource.eventhub.name
  servicebus_namespace      = azapi_resource.eventhub_namespace.name
  shared_access_policy_key  = data.azurerm_eventhub_namespace.eventhub_namespaces.default_primary_key
  shared_access_policy_name = "RootManageSharedAccessKey"

  serialization {
    type     = "Json"
    encoding = "UTF8"
  }
}






resource "azurerm_stream_analytics_output_blob" "job_output" {
  name                      = "output-to-blob-storage"
  stream_analytics_job_name = azurerm_stream_analytics_job.job.name
  resource_group_name       = var.rg_name
  storage_account_name      = azurerm_storage_account.storage_account.name
  storage_account_key       = azurerm_storage_account.storage_account.primary_access_key
  storage_container_name    = azurerm_storage_container.analytics_container.name
  path_pattern              = "analytics/output/{date}/{time}"
  date_format               = "yyyy-MM-dd"
  time_format               = "HH"
  batch_min_rows            = 10000
  batch_max_wait_time       = "00:00:30"


  serialization {
    type = "Parquet"
    # encoding        = "UTF8"
    # field_delimiter = ","
  }
}

resource "azurerm_stream_analytics_job_schedule" "now" {
  stream_analytics_job_id = azurerm_stream_analytics_job.job.id
  start_mode              = "CustomTime"
  start_time              = "2022-09-21T00:00:00Z"

  depends_on = [
    azurerm_stream_analytics_job.job,
    azurerm_stream_analytics_stream_input_eventhub_v2.job_input,
    azurerm_stream_analytics_output_blob.job_output,
  ]
}