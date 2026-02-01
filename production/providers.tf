terraform {


  backend "azurerm" {


    # storage_account_name = local.backend_storage      # Can be passed via `-backend-config=`"storage_account_name=<storage account name>"` in the `init` command.
    # container_name       = local.backend_container    # Can be passed via `-backend-config=`"container_name=<container name>"` in the `init` command.
    key = "prod.terraform.tfstate" # Can be passed via `-backend-config=`"key=<blob key name>"` in the `init` command.
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
  features {

    databricks_workspace {
      force_delete = false
    }

    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }

    log_analytics_workspace {
      permanently_delete_on_destroy = true
    }

    subscription {
      prevent_cancellation_on_destroy = false
    }

  }
}
provider "azapi" {}

provider "databricks" {
  host                        = data.azurerm_key_vault_secret.databricks_workspace_url.value
  azure_workspace_resource_id = data.azurerm_key_vault_secret.databricks_workspace_id.value
  # auth_type                   = "azure-cli"

}


