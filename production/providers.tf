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



# resource "null_resource" "workspace_details" {
#   triggers = {
#     dr_client_id = local.msi_id
#   }

#   provisioner "local-exec" {
#     command = "az login --service-principal -u $ARM_CLIENT_ID -t $ARM_TENANT_ID --federated-token \"$(cat $ARM_OIDC_TOKEN_FILE_PATH)\""
#   }
# }

data "terraform_remote_state" "foo" {
  backend = "azurerm"
  config = {

    storage_account_name = "dagsterinarian27"       # Can be passed via `-backend-config=`"storage_account_name=<storage account name>"` in the `init` command.
    container_name       = "tfstate"                # Can be passed via `-backend-config=`"container_name=<container name>"` in the `init` command.
    key                  = "prod.terraform.tfstate" # Can be passed via `-backend-config=`"key=<blob key name>"` in the `init` command.
  }

}





provider "databricks" {
  host                        = data.terraform_remote_state.foo.outputs.databricks_workspace_url #module.data-workflow.databricks_workspace_url         #: data.terraform_remote_state.foo.outputs.databricks_workspace_url
  azure_workspace_resource_id = data.terraform_remote_state.foo.outputs.databricks_workspace_resource_id #module.data-workflow.databricks_workspace_resource_id #: data.terraform_remote_state.foo.outputs.databricks_workspace_resource_id
  auth_type                   = "azure-cli"
  # alias = "workspace"
}




# data "azurerm_client_config" "current" {}

# provider "databricks" {
#   alias      = "account"
#   host       = "https://accounts.azuredatabricks.net"
#   # account_id = "https://accounts.azuredatabricks.net" #data.azurerm_client_config.current.client_id
# }
