terraform {

  required_providers {
    databricks = {
      source = "databricks/databricks"
      # configuration_aliases = [databricks.workspace]
      # version= "1.100.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.0"
    }
  }
}

provider "databricks" {
  host                        = var.workspace_url
  azure_workspace_resource_id = var.workspace_id
  # auth_type                   = "azure-cli"
  
}

