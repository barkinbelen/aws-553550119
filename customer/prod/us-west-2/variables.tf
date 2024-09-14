variable "project_name" {
  type        = string
  description = "Project name"
  default     = "Customer"
}

variable "profile_name" {
  type        = string
  description = "AWS Profile to be used to create/access resources"
  default     = "prod-customer"
}

variable "env" {
  type        = string
  description = "Environment name"
  default     = "Prod"
}

variable "region" {
  type        = string
  description = "The deployment region"
  default     = "us-west-2"
}
