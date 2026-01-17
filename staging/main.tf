locals {
  environment = var.environment
  name        = azapi_resource.env.name
  region      = "Germany West Central"
  app_name    = "azureadmin"
  domain      = "bdatanet.tech"
  prefix      = "bdn"
  msi_oid     = azapi_resource.managed_identity.output.properties.principalId
  msi_sid     = azapi_resource.managed_identity.id
  msi_id      = azapi_resource.managed_identity.output.properties.clientId

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
  location = "Germany West Central"
  name     = "${random_pet.rg_name.id}-${var.environment}"
}

resource "azapi_resource" "managed_identity" {
  body                      = {}
  location                  = local.region
  name                      = "${local.environment}-service_account"
  parent_id                 = azapi_resource.env.id
  schema_validation_enabled = true
  type                      = "Microsoft.ManagedIdentity/userAssignedIdentities@2025-01-31-preview"
  response_export_values    = ["*"]
}


resource "azurerm_role_assignment" "roleAssignment1" {
  scope                = azapi_resource.env.id
  role_definition_name = "Contributor"
  principal_id         = local.msi_oid
}

resource "azurerm_role_assignment" "roleAssignment2" {
  scope                = azapi_resource.env.id
  role_definition_name = "User Access Administrator"
  principal_id         = local.msi_oid
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
# module "data-workflow" {
#   source = "../modules/stream-analytics"

#   # Input Variables
#   environment    = local.environment
#   location       = local.region
#   prefix         = local.prefix
#   owner          = "architect"
#   team           = var.team
#   rg_id          = azapi_resource.env.id
#   rg_parent_id   = azapi_resource.env.parent_id
#   identity_id    = local.msi_id
#   identity_subid = local.msi_sid
#   rg_name        = local.name


#   depends_on = [module.global]
# }

# module "databricks" {
#   source = "../modules/databricks"

#   # Input variables
#   environment  = local.environment
#   location     = local.region
#   prefix       = local.prefix
#   owner        = "architect"
#   team         = var.team
#   rg_id        = azapi_resource.env.id
#   rg_parent_id = azapi_resource.env.parent_id
#   # identity_objid                  = local.msi_oid
#   # identity_clientid               = local.msi_id
#   identity_subid                  = local.msi_sid
#   workspace_url                   = module.data-workflow.databricks_workspace_url
#   workspace_id                    = module.data-workflow.databricks_workspace_id
#   service_connector               = module.data-workflow.databricks_service_connector
#   cluster_autotermination_minutes = 60
#   cluster_num_workers             = 1
#   cluster_data_security_mode      = "USER_ISOLATION"
#   # providers = {
#   #   databricks.workspace = databricks.workspace
#   #   databricks.account   = databricks.account
#   # }


#   depends_on = [module.global, module.data-workflow]
# }

module "app-service" {
  source = "../modules/app-services"

  #  Input Variables
  environment           = local.environment
  location              = local.region
  owner                 = "architect"
  team                  = var.team
  identity_id           = local.msi_sid
  identity_clientid     = local.msi_id
  identity_objid        = local.msi_oid
  registry_url          = module.global.registry_url
  registry_user         = module.global.registry_user
  registry_pass         = module.global.registry_pass
  logAnalyticsWorkspace = module.global.logAnalyticsWorkspace
  appinsights           = module.global.AppInsightsWorkspace
  rg_name               = local.name

  depends_on = [module.global]
}

module "dev-environments" {
  source = "../modules/dev-env"

  #  Input Variables
  environment           = local.environment
  rg_id                 = azapi_resource.env.id
  location              = local.region
  username              = local.app_name
  nsg_id                = module.global.rg_vnet_nsg
  nic_id                = module.global.rg_vnet_nic
  owner                 = "architect"
  team                  = var.team
  identity_id           = local.msi_sid
  identity_clientid     = local.msi_id
  registry_url          = module.global.registry_url
  registry_user         = module.global.registry_user
  registry_pass         = module.global.registry_pass
  logAnalyticsWorkspace = module.global.AppInsightsWorkspace
  appinsights           = module.global.AppInsightsWorkspace
  rg_name               = local.name

  depends_on = [module.global]
}



