

data "azurerm_client_config" "current" {}
data "azurerm_key_vault" "key_vault" {
  name                = module.global.key_vault_name
  resource_group_name = module.global.rg_name

  depends_on = [module.global]
}
ephemeral "azurerm_key_vault_secret" "databricks_workspace_id" {
  key_vault_id = data.azurerm_key_vault.key_vault.id
  name         = "databricks_workspace_resource_id"
}

ephemeral "azurerm_key_vault_secret" "databricks_workspace_url" {
  key_vault_id = data.azurerm_key_vault.key_vault.id
  name         = "databricks_workspace_url"
}

locals {
  environment = var.environment
  name        = azapi_resource.env.name
  region      = "West US 2"
  app_name    = "azureadmin"
  domain      = "bdatanet.tech"
  prefix      = "ong"
  msi_oid     = resource.azapi_resource.identity.output.properties.object_id
  msi_sid     = resource.azapi_resource.identity.id
  msi_id      = resource.azapi_resource.identity.output.properties.client_id
}

resource "random_string" "staging" {
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

  depends_on = [data.azurerm_user_assigned_identity.home]
}

resource "azapi_resource" "identity" {
  type      = "Microsoft.ManagedIdentity/userAssignedIdentities@2023-06-01"
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
  rg_name  = azapi_resource.env.name
  location = local.region
  # key_name = "prod_"
  prefix      = local.prefix
  environment = local.name


}


# Analytics Module
module "data-workflow" {
  source = "../modules/stream-analytics"
  # Input Variables
  environment    = local.environment
  location       = local.region
  prefix         = local.prefix
  owner          = "architect"
  team           = var.team
  rg_parent_id   = azapi_resource.env.parent_id
  identity_id    = local.msi_id
  identity_objid = local.msi_oid
  identity_subid = local.msi_sid
  key_vault      = module.global.key_vault_name
  rg_name        = local.name


  depends_on = [module.global]
}

# import {
#   to = module.databricks.databricks_external_location.some
#    id = "external"
# }



module "databricks" {
  source = "../modules/databricks"

  # Input variables
  environment                     = local.environment
  location                        = local.region
  prefix                          = local.prefix
  owner                           = "architect"
  team                            = var.team
  rg_name                         = azapi_resource.env.name
  rg_parent_id                    = azapi_resource.env.parent_id
  identity_objid                  = local.msi_oid
  identity_clientid               = local.msi_id
  identity_subid                  = local.msi_sid
  storage_account                 = module.data-workflow.storage_account_name
  storage_container               = module.data-workflow.storage_container_name
  service_connector               = module.data-workflow.databricks_service_connector
  cluster_autotermination_minutes = 60
  cluster_num_workers             = 1
  cluster_data_security_mode      = "USER_ISOLATION"
  jobsource_url                   = var.jobsource_url
  github_email                    = var.github_email
  github_pat                      = var.github_pat
  github_username                 = var.github_username
  workspace_name                  = module.data-workflow.databricks_workspace_name
  key_vault                       = module.global.key_vault_name


  depends_on = [module.global, module.data-workflow]
}

output "rg_name" {
  value = azapi_resource.env.name
}

output "databricks_workspace_url" {
  value = module.data-workflow.databricks_workspace_url
}

output "databricks_workspace_id" {
  value = module.data-workflow.databricks_workspace_id
}

output "databricks_workspace_resource_id" {
  value = module.data-workflow.databricks_workspace_resource_id
}

