terraform {


  backend "azurerm" {


    storage_account_name = "dagsterinarian27"       # Can be passed via `-backend-config=`"storage_account_name=<storage account name>"` in the `init` command.
    container_name       = "tfstate"                # Can be passed via `-backend-config=`"container_name=<container name>"` in the `init` command.
    key                  = "prod.terraform.tfstate" # Can be passed via `-backend-config=`"key=<blob key name>"` in the `init` command.
  }

  required_providers {
    databricks = {
      source = "databricks/databricks"
      # version = "~>1.100.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~>2.8.0"
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
  host                        = can(local.datab_url) ? local.datab_url : data.terraform_remote_state.foo.outputs.databricks_workspace_url
  azure_workspace_resource_id = can(local.datab_rid) ? local.datab_rid : data.terraform_remote_state.foo.outputs.databricks_workspace_resource_id
  # auth_type                   = "azure-cli"

}


