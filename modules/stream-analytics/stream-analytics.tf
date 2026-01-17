
resource "random_pet" "stream_analytics_job_name" {
  prefix = var.prefix
}

resource "azurerm_stream_analytics_job" "job" {
  name                                     = random_pet.stream_analytics_job_name.id
  resource_group_name                      = var.environment
  location                                 = var.location
  streaming_units                          = var.number_of_streaming_units
  events_out_of_order_max_delay_in_seconds = 0
  events_late_arrival_max_delay_in_seconds = 5
  data_locale                              = "en-US"
  events_out_of_order_policy               = "Adjust"
  output_error_policy                      = "Stop"

  transformation_query = <<QUERY
SELECT
    *
INTO
    [YourOutputAlias]
FROM
    [YourInputAlias]
QUERY

}

resource "azurerm_stream_analytics_stream_input_eventhub_v2" "job_input" {
  name                         = "eventhub-stream-input"
  stream_analytics_job_id      = azurerm_stream_analytics_job.job.id
  eventhub_consumer_group_name = azurerm_eventhub_consumer_group.upstream_stream.name
  eventhub_name                = azapi_resource.eventhub.name
  servicebus_namespace         = azapi_resource.eventhub_namespace.name
  shared_access_policy_key     = azapi_resource.eventhub_namespace.default_primary_key
  shared_access_policy_name    = "RootManageSharedAccessKey"

  serialization {
    type     = "Json"
    encoding = "UTF8"
  }
}

resource "azurerm_stream_analytics_output_blob" "job_output" {
  name                      = "output-to-blob-storage"
  stream_analytics_job_name = azurerm_stream_analytics_job.job.name
  resource_group_name       = var.environment
  storage_account_name      = azurerm_storage_account.analytics_storage.name
  storage_account_key       = azurerm_storage_account.analytics_storage.primary_access_key
  storage_container_name    = azurerm_storage_container.analytics_container.name
  path_pattern              = "analytics/output/{date}/{time}"
  date_format               = "yyyy-MM-dd"
  time_format               = "HH"

  serialization {
    type            = "parquet"
    # encoding        = "UTF8"
    field_delimiter = ","
  }
}