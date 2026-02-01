


# Generate a random integer to create a globally unique name
resource "random_integer" "uid" {
  min = 10000
  max = 99999

  keepers = {
    constant = local.name
  }

}


data "azurerm_client_config" "current" {}

data "azurerm_databricks_workspace" "databricks_workspace" {
  name                = "ong_streamWorkspace-${random_integer.uid.result}"
  resource_group_name = local.name
}

data "azurerm_key_vault" "key_vault" {
  name                = module.global.key_vault_name
  resource_group_name = local.name
}

data "azurerm_key_vault_secret" "databricks_workspace_id" {
  key_vault_id = data.azurerm_key_vault.key_vault.id
  name         = "databricks-workspace-resource-id"

}

data "azurerm_key_vault_secret" "databricks_workspace_url" {
  key_vault_id = data.azurerm_key_vault.key_vault.id
  name         = "databricks-workspace-url"

}

locals {
  environment        = var.environment
  name               = azapi_resource.env.name
  region             = "Central US"
  app_name           = "azureadmin"
  domain             = "bdatanet.tech"
  prefix             = "ong"
  controlid_name     = "assemblymanager"
  environmentid_name = "assemblymanager"
  workspace_id       = data.azurerm_key_vault_secret.databricks_workspace_id.value
  workspace_url      = data.azurerm_key_vault_secret.databricks_workspace_url.value

}

resource "random_string" "production" {
  length  = 15
  lower   = true
  numeric = true
  special = false
  upper   = false
}

resource "random_pet" "rg_name" {
  prefix = local.prefix
}

# Create a resource group using the generated environment name
resource "azapi_resource" "env" {
  type     = "Microsoft.Resources/resourceGroups@2020-06-01"
  location = local.region
  name     = "${random_pet.rg_name.id}-${var.environment}"

}

resource "azapi_resource" "identity" {
  type      = "Microsoft.ManagedIdentity/userAssignedIdentities@2025-01-31-preview"
  location  = local.region
  name      = "service-account"
  parent_id = azapi_resource.env.id
  tags = {
    environment = local.environment
    prefix      = local.prefix
    owner       = "architect"
    team        = var.team
  }
}


module "global" {
  source = "../global"

  # Input Variables
  rg_name            = local.name
  location           = local.region
  key_name           = "prod_"
  prefix             = local.prefix
  environment        = local.name
  environmentid_name = local.environmentid_name
  github_email       = var.github_email
  rg_parent_id       = azapi_resource.env.parent_id
  owner              = "architect"
  team               = var.team

}


# Analytics Module
module "data-workflow" {
  source = "../modules/stream-analytics"
  # Input Variables
  environment        = local.environment
  location           = local.region
  prefix             = local.prefix
  owner              = "architect"
  team               = var.team
  rg_parent_id       = azapi_resource.env.parent_id
  environmentid_name = local.environmentid_name
  controlid_name     = local.controlid_name
  rg_name            = local.name
  key_vault          = module.global.key_vault_name
  random_integer     = random_integer.uid.result

  depends_on = [module.global]
}

module "databricks" {
  source = "../modules/databricks"

  # Input variables
  environment                     = local.environment
  location                        = local.region
  prefix                          = local.prefix
  owner                           = "architect"
  team                            = var.team
  rg_parent_id                    = azapi_resource.env.parent_id
  controlid_name                  = local.controlid_name
  environmentid_name              = local.environmentid_name
  storage_account                 = module.data-workflow.storage_account_name
  storage_container               = module.data-workflow.storage_container_name
  service_connector               = module.data-workflow.databricks_service_connector
  cluster_autotermination_minutes = 60
  cluster_num_workers             = 1
  cluster_data_security_mode      = "USER_ISOLATION"
  key_vault                       = module.global.key_vault_name
  github_pat                      = var.github_pat
  github_username                 = var.github_username
  github_email                    = var.github_email
  jobsource_url                   = var.jobsource_url
  slack_key                       = var.slack_key
  workspace_name                  = module.data-workflow.databricks_workspace_name
  rg_name                         = local.name

  depends_on = [module.data-workflow, data.azurerm_key_vault_secret.databricks_workspace_id]


}

