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

variable "cidr_block" {
  type        = string
  description = "CIDR range of VPC"
  default     = "10.0.0.0/16"
}

variable "subnet_count" {
  type        = number
  description = "Number of subnets to be created"
  default     = 2
}

variable "public_subnet_suffixes" {
  type        = list(string)
  description = "Public Subnet CIDR values"
  default     = ["1.0/24", "2.0/24", "3.0/24"]
}

variable "private_subnet_suffixes" {
  type        = list(string)
  description = "Private Subnet CIDR values"
  default     = ["4.0/24", "5.0/24", "6.0/24"]
}

variable "extra_tags" {
  type        = map(string)
  description = "Extra tags to be used for created resources"
  default = {
    Application = "Customer"
    Environment = "Prod"
    Owner       = "Devops Admin"
    Install     = "Terraform"
  }
}

variable "instance_name" {
  description = "Value of the Name tag for the EC2 instance"
  type        = string
  default     = "Web-Server"
}

variable "instance_type" {
  description = "Value of instance type for the EC2 instance"
  type        = string
  default     = "t2.micro"
}

variable "ami_id" {
  description = "Value of AMI ID for the EC2 instance"
  type        = string
  default     = "ami-0bfddf4206f1fa7b9"
}
