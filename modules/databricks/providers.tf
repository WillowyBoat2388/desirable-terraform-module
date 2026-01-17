terraform {

  required_providers {
    databricks = {
      source = "databricks/databricks"
      # configuration_aliases = [databricks.account, databricks.workspace]
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.0"
    }
  }
}

