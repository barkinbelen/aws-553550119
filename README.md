# Terraform AWS Infrastructure Setup

This repository contains Terraform code to deploy infrastructure on AWS, including a VPC, Auto Scaling Group, an Application Load Balancer (ALB), CloudWatch Alarms, SNS Topic and an S3 bucket for web content.

# Repository Structure

The repository is structured with two main modules:

- VPC Module: This module provisions the required VPC resources, such as subnets, internet gateways, and NAT gateways.
- EC2 Module: This module handles the creation of Auto Scaling Group (ASG), CloudWatch Logs and Alarms, Application Load Balancer (ALB), IAM roles, Security Groups and SNS Topic.

# How to Use

1. Configure AWS Backend

   - Ensure that the backend.tf file is properly configured to store the Terraform state in the specified S3 bucket and DynamoDB table.

2. Initialize Terraform
   - Before deploying resources, initialize the Terraform working directory:

```
terraform init
```

4. Customize Variables
   - Update the variables.tf file or provide a terraform.tfvars file with values that fit your environment. Key variables to customize:

Run the following commands to create the infrastructure:

```
terraform plan
terraform apply
```

5. Destroy the Infrastructure
   When you no longer need the infrastructure, you can destroy it using:

```
terraform destroy
```

## Modules

### VPC Module

The VPC module creates the following resources:

- A VPC with the specified CIDR block
- Public and private subnets across the specified availability zones
- An Internet Gateway (IGW) for the public subnets
- NAT Gateways for the private subnets

### EC2 Module

The EC2 module creates:

- Auto Scaling Group (ASG) for EC2 instances
- Application Load Balancer (ALB)
- IAM roles and policies for the instances
- Security Groups to control access
- CloudWatch Logs and Alarms for monitoring
- SNS Topic
- SNS Topic subscription

## Resources

### S3 Bucket

An S3 bucket is created to store web content. By default, the index.html file is uploaded to the bucket.

## Variables

| Variable                           | Description                                       | Example                               |
| ---------------------------------- | ------------------------------------------------- | ------------------------------------- |
| `project_name`                     | Project name for tagging resources                | `Customer`                            |
| `env`                              | Environment name (Prod, Dev, etc.)                | `Prod`                                |
| `region`                           | AWS Region to deploy the resources                | `us-west-2`                           |
| `cidr_block`                       | CIDR range of the VPC                             | `10.0.0.0/16`                         |
| `subnet_count`                     | Number of public and private subnets              | `2`                                   |
| `public_subnet_suffixes`           | CIDR suffixes for public subnets                  | `["1.0/24", "2.0/24"]`                |
| `private_subnet_suffixes`          | CIDR suffixes for private subnets                 | `["4.0/24", "5.0/24"]`                |
| `instance_name`                    | Name tag for the EC2 instances                    | `Web-Server`                          |
| `instance_type`                    | EC2 instance type                                 | `t2.micro`                            |
| `ami_id`                           | AMI ID for the EC2 instances                      | `ami-0bfddf4206f1fa7b9`               |
| `extra_tags`                       | Additional tags for resources                     | See `variables.tf`                    |
| `aws_sns_topic_subscription_email` | Email address of the AWS SNS topic subscription   | `devops-admin@example.com`            |
| `web_content_bucket_name`          | Name of the S3 bucket where web content is stored | `customer-prod-web-content-553550119` |

## Module Outputs

### Root Module

| Output              | Description       |
| ------------------- | ----------------- |
| `load_balancer_url` | Load Balancer URL |

### VPC Module

| Output                    | Description                     |
| ------------------------- | ------------------------------- |
| `vpc_id`                  | ID of the VPC created           |
| `public_subnets`          | IDs of the public subnets       |
| `private_subnets`         | IDs of the private subnets      |
| `public_route_table_ids`  | IDs of the public route tables  |
| `private_route_table_ids` | IDs of the private route tables |

### EC2 Module

| Output              | Description       |
| ------------------- | ----------------- |
| `load_balancer_url` | Load Balancer URL |
