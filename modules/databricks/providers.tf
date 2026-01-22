terraform {

  required_providers {
    databricks = {
      source = "databricks/databricks"
    
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.0"
    }
  }
}
