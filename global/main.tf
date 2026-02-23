


locals {
  current_user_id = data.azurerm_user_assigned_identity.home.client_id
  tags = {
    Environment  = var.environment
    team         = var.team
    owner        = var.owner
    subscription = var.rg_parent_id
  }

}

data "azurerm_user_assigned_identity" "home" {
  name                = var.environmentid_name
  resource_group_name = var.parent
}

data "azurerm_resource_group" "resourceGroup" {
  name = var.rg_name
}
data "azurerm_subscription" "current" {
}


## Resource Group development default resources
resource "azapi_resource" "AppInsights" {
  body = {
    etag = "\"6f0192e9-0000-1500-0000-692efc1f0000\""
    kind = "web"
    properties = {
      Application_Type                = "web"
      Flow_Type                       = "Redfield"
      IngestionMode                   = "LogAnalytics"
      Request_Source                  = "IbizaWebAppExtensionCreate"
      SamplingPercentage              = null
      WorkspaceResourceId             = azapi_resource.logAnalyticsWorkspace.id
      publicNetworkAccessForIngestion = "Enabled"
      publicNetworkAccessForQuery     = "Enabled"
    }
  }
  ignore_casing             = false
  ignore_missing_property   = true
  ignore_null_property      = false
  location                  = var.location
  name                      = "${var.environment}_client_insights"
  parent_id                 = data.azurerm_resource_group.resourceGroup.id
  schema_validation_enabled = true
  type                      = "microsoft.insights/components@2020-02-02-preview"

  depends_on = [azapi_resource.logAnalyticsWorkspace]
  lifecycle {
    ignore_changes = [body.etag] # Prevents 'id' from causing replacement on updates
  }
}

resource "azapi_resource" "logAnalyticsWorkspace" {
  body = {
    etag = "\"1e02a6cc-0000-1500-0000-692efc110000\""
    properties = {
      features = {
        enableLogAccessUsingOnlyResourcePermissions = true
        legacy                                      = 0
        searchVersion                               = 1
      }
      publicNetworkAccessForIngestion = "Enabled"
      publicNetworkAccessForQuery     = "Enabled"
      retentionInDays                 = 30
      sku = {
        name = "PerGB2018"
      }
      workspaceCapping = {
        dailyQuotaGb = -1
      }
    }
  }
  ignore_casing             = false
  ignore_missing_property   = true
  ignore_null_property      = false
  location                  = var.location
  name                      = "DefaultWorkspace-3454637f"
  parent_id                 = data.azurerm_resource_group.resourceGroup.id
  schema_validation_enabled = true
  type                      = "Microsoft.OperationalInsights/workspaces@2025-02-01"
  lifecycle {
    ignore_changes = [body.etag] # Prevents 'id' from causing replacement on updates
  }
}

resource "random_string" "azurerm_key_vault_name" {
  length  = 13
  lower   = true
  numeric = false
  special = false
  upper   = false

  keepers = {
    constant = data.azurerm_resource_group.resourceGroup.id
  }

}

resource "azurerm_key_vault" "vault" {
  name                       = coalesce(var.vault_name, "vault-${random_string.azurerm_key_vault_name.result}")
  location                   = var.location
  resource_group_name        = var.environment
  tenant_id                  = data.azurerm_user_assigned_identity.home.tenant_id
  sku_name                   = var.sku_name
  soft_delete_retention_days = 7

  access_policy {
    tenant_id = data.azurerm_user_assigned_identity.home.tenant_id
    object_id = data.azurerm_user_assigned_identity.home.principal_id

    key_permissions     = var.key_permissions
    secret_permissions  = var.secret_permissions
    storage_permissions = var.storage_permissions
  }

  # rbac_authorization_enabled = true

  enabled_for_template_deployment = true

  tags = local.tags

}

resource "random_string" "azurerm_key_vault_secret" {
  length  = 13
  lower   = true
  numeric = false
  special = false
  upper   = false

  keepers = {
    constant = data.azurerm_resource_group.resourceGroup.id
  }

  depends_on = [azurerm_key_vault.vault]
}

resource "azurerm_subscription_cost_management_view" "example" {
  name         = "Streaming View"
  display_name = "Cost View per Week"
  chart_type   = "StackedColumn"
  accumulated  = true

  subscription_id = data.azurerm_subscription.current.id

  report_type = "Usage"
  timeframe   = "WeekToDate"

  dataset {
    granularity = "Daily"

    aggregation {
      name        = "totalCost"
      column_name = "Cost"
    }
  }
  pivot {
    type = "Dimension"
    name = "ServiceName"
  }
  pivot {
    type = "Dimension"
    name = "ResourceLocation"
  }
  pivot {
    type = "Dimension"
    name = "ResourceGroupName"
  }
}

resource "azurerm_cost_management_scheduled_action" "example" {
  name         = "examplescheduledaction"
  display_name = "Report Last 6 Months"

  view_id = azurerm_subscription_cost_management_view.example.id

  email_address_sender = "platformteam@test.com"
  email_subject        = "Cost Management Report"
  email_addresses      = [var.github_email]
  message              = "Hi all, take a look at today's spending!"

  frequency  = "Daily"
  start_date = "2026-02-02T00:00:00Z"
  end_date   = "2026-12-02T00:00:00Z"
}






