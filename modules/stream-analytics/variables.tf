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

variable "rg_parent_id" {
  description = "parent id of the resource group"
  type        = string
}

variable "environmentid_name" {
  description = "name of the managed identity created within the environment"
  type        = string
}

variable "controlid_name" {
  description = "name of the managed identity automating deployment of the environment"
  type        = string
}

# variable "identity_objid" {
#   description = "managed identity object id"
#   type        = string
# }

variable "number_of_streaming_units" {
  type        = number
  description = "Number of streaming units."
  default     = 1
  validation {
    condition     = contains([1, 3, 6, 12, 18, 24, 30, 36, 42, 48], var.number_of_streaming_units)
    error_message = "Invalid value for: number_of_streaming_units. The value should be one of the following: 1, 3, 6, 12, 18, 24, 30, 36, 42, 48."
  }
}

variable "prefix" {
  description = "The prefix used for all resources in this example"
}

variable "rg_name" {
  description = "environment base resource group name"
  type        = string
}

variable "key_vault" {
  description = "Environment Key Vault"
  type        = string
  sensitive   = true
}  