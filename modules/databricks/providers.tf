terraform {

  required_providers {
    databricks = {
      source = "databricks/databricks"
      # version= "1.100.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.0"
    }
  }
}

