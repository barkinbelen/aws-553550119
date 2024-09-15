variable "project_name" {
  description = "Project name"
  type        = string
}

variable "env" {
  description = "Environment name"
  type        = string
}

variable "ami_id" {
  description = "AMI ID"
  type        = string
}

variable "instance_type" {
  description = "Instance type"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Private subnet IDs"
  type        = list(string)
}

variable "instance_name" {
  description = "Instance name"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC where the instance will be created"
  type        = string
}

variable "web_content_s3_bucket" {
  description = "S3 bucket where web content is stored"
  type = object({
    bucket = string
    arn    = string
  })
}

variable "extra_tags" {
  description = "Extra tagst to be used for created resources"
  type        = map(string)
  default     = {}
}
