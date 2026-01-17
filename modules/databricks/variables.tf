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

variable "rg_id" {
  description = "subscription id of the resource group"
  type        = string
}

variable "rg_parent_id" {
  description = "parent id of the resource group"
  type        = string
}

variable "identity_subid" {
  description = "id of the user-assigned identity for"
  type        = string
}

# variable "identity_clientid" {
#   description = "managed identity client id"
#   type        = string
# }

# variable "identity_objid" {
#   description = "managed identity object id"
#   type        = string
# }

variable "cluster_autotermination_minutes" {}
variable "cluster_num_workers" {}
variable "cluster_data_security_mode" {}

variable "workspace_id" {
  description = "databricks workspace id"
  type        = string
}

variable "workspace_url" {
  description = "databricks workspace url"
  type        = string
}

variable "service_connector" {
  description = "databricks service connector id"
  type        = string
}

variable "prefix" {
  description = "The prefix used for all resources in this example"
}


