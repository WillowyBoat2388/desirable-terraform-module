# Environment Variables

variable "backend_storage" {
  description = "storage account name for terraform state storage"
  type        = string
}

variable "backend_container" {
  description = "storage container name for terraform state storage"
  type        = string
}

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

variable "github_pat" {
  description = "github personal access token"
  sensitive   = true
}

variable "github_username" {
  description = "github username for job source"
}

variable "github_email" {
  description = "github email for job source"
}

variable "jobsource_url" {
  description = "github job source url"
}

variable "slack_key" {
  description = "slack webhook key"
  sensitive   = true
}




