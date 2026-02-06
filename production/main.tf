


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



locals {
  environment        = var.environment
  name               = azapi_resource.env.name
  region             = "East US 2"
  parent             = "floor_zero"
  domain             = "bdatanet.tech"
  prefix             = "ong"
  controlid_name     = "floor_zero_admin"
  environmentid_name = "floor_zero_admin"

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
  parent             = local.parent
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
  parent             = local.parent
  depends_on         = [module.global]
}



