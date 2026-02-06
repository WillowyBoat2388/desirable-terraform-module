# General Variables

variable "location" {
  description = "Location of the resource group"
  type        = string
  default     = "Germany West Central"
}

variable "owner" {
  description = "Owner of the resource"
  type        = string
  default     = "architect"
}

variable "team" {
  description = "Team managing resource"
  type        = string
  default     = "engineering"
}

variable "environment" {
  description = "Environment of the resource"
  type        = string
  default     = "staging"
}

variable "rg_name" {
  description = "name of the resource group"
  type        = string
}

variable "rg_parent_id" {
  description = "parent id of the resource group"
  type        = string
}

variable "environmentid_name" {
  description = "name of the managed identity created in the environment"
  type        = string
}

variable "controlid_name" {
  description = "orchestrating managed identity name"
  type        = string
}

variable "parent" {
  description = "managed identity resource group"
  type        = string
}

variable "cluster_autotermination_minutes" {}
variable "cluster_num_workers" {}
variable "cluster_data_security_mode" {}


variable "workspace_name" {
  description = "databricks workspace name"
  type        = string
}

variable "service_connector" {
  description = "databricks service connector id"
  type        = string
}

variable "prefix" {
  description = "The prefix used for all resources in this example"
}

variable "storage_container" {
  description = "The name of the storage container to create"
  type        = string
}

variable "storage_account" {
  description = "The name of the storage account to create the container in"
  type        = string
}

variable "github_pat" {
  description = "The github personal access token for git repo integration"
  sensitive   = true
}

variable "jobsource_url" {
  description = "The url of the github repo for job source"
  type        = string
}

variable "github_username" {
  description = "The username for the github user"
  type        = string
}

variable "github_email" {
  description = "The email for the github user"
  type        = string
}

variable "slack_key" {
  description = "The slack webhook key"
  sensitive   = true
}



variable "key_vault" {
  description = "keyvault name for retrieving environment secrets"
  type        = string
  sensitive   = true
}