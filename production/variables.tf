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