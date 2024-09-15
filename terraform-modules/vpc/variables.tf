variable "project_name" {
  description = "Project name"
  type        = string
}

variable "env" {
  description = "Environment name"
  type        = string
}

variable "region" {
  description = "AWS Region"
  type        = string
}

variable "subnet_count" {
  description = "Number of subnets to be created"
  type        = number
  default     = 3
}

variable "cidr_block" {
  type        = string
  description = "CIDR range of VPC"
}

variable "extra_tags" {
  description = "Extra tagst to be used for created resources"
  type        = map(string)
  default     = {}
}

variable "public_subnet_suffixes" {
  description = "Public Subnet CIDR suffix values"
  type        = list(string)
}

variable "private_subnet_suffixes" {
  description = "Private Subnet CIDR suffix values"
  type        = list(string)
}
