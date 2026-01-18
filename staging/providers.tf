terraform {


  backend "azurerm" {
    # use_azuread_auth     = true                     # Can also be set via `ARM_USE_AZUREAD` environment variable.
    # use_oidc             = true                     # Can also be set via `ARM_USE_CLI` environment variable.
    storage_account_name = "bdncloudcontrol"        # Can be passed via `-backend-config=`"storage_account_name=<storage account name>"` in the `init` command.
    container_name       = "tfstate"                # Can be passed via `-backend-config=`"container_name=<container name>"` in the `init` command.
    key                  = "prod.terraform.tfstate" # Can be passed via `-backend-config=`"key=<blob key name>"` in the `init` command.
  }

  required_providers {
    databricks = {
      source = "databricks/databricks"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~>2.6.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.0"
    }
  }
}

provider "azurerm" {
  features {}
}
provider "azapi" {}


provider "databricks" {
  host                        = module.data-workflow.databricks_workspace_url
  azure_workspace_resource_id = module.data-workflow.databricks_workspace_resource_id
  auth_type                   = "github-oidc-azure"
  # alias = "workspace"
}




# data "azurerm_client_config" "current" {}

# provider "databricks" {
#   alias      = "account"
#   host       = "https://accounts.azuredatabricks.net"
#   # account_id = "https://accounts.azuredatabricks.net" #data.azurerm_client_config.current.client_id
# }
