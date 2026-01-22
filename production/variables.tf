# Environment Variables

variable "team" {
  description = "resource group management team"
  type        = string
  default     = "engineering"
}

variable "environment" {
  description = "Environment name "
  type        = string
  default     = "production"
}

variable "this_env_workspace" {
  description = "Environment workspace  info"
  type        = list(string)
  default     = [module.databricks.workspace_url, module.databricks.workspace_resource_id]
}