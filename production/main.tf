

data "azurerm_client_config" "current" {}

data "azurerm_user_assigned_identity" "home" {
  name                = "ong-rw"
  resource_group_name = "management"
}



locals {
  environment = var.environment
  name        = azapi_resource.env.name
  region      = "West US 2"
  app_name    = "azureadmin"
  domain      = "bdatanet.tech"
  prefix      = "ong"
  msi_oid     = data.azurerm_client_config.current.object_id
  msi_sid     = data.azurerm_user_assigned_identity.home.id
  msi_id      = data.azurerm_client_config.current.client_id

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
}

module "global" {
  source = "../global"

  # Input Variables
  rg_id    = azapi_resource.env.id
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
  rg_id          = azapi_resource.env.id
  rg_parent_id   = azapi_resource.env.parent_id
  identity_id    = local.msi_id
  identity_objid = local.msi_oid
  identity_subid = local.msi_sid
  rg_name        = local.name


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
  rg_id                           = azapi_resource.env.id
  rg_parent_id                    = azapi_resource.env.parent_id
  identity_objid                  = local.msi_oid
  identity_clientid               = local.msi_id
  identity_subid                  = local.msi_sid
  workspace_url                   = module.data-workflow.databricks_workspace_url
  workspace_id                    = module.data-workflow.databricks_id
  cluster_autotermination_minutes = 60
  cluster_num_workers             = 1
  cluster_data_security_mode      = "USER_ISOLATION"
  # providers = {
  #   databricks.workspace = databricks.workspace
  #   databricks.account   = databricks.account
  # }


  depends_on = [module.global, module.data-workflow]
}
