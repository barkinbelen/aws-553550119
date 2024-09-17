# Terraform AWS Infrastructure Setup

This repository contains Terraform code for deploying AWS infrastructure, including a VPC, Auto Scaling Group (ASG), CloudWatch Alarms, an SNS Topic, and an S3 bucket for hosting web content via Nginx within the ASG.

# Repository Structure

The repository is structured with two main modules:

- VPC Module: This module provisions the required VPC resources, such as subnets, internet gateways, and NAT gateways.
- ASG Module: This module handles the creation of an Auto Scaling Group (ASG), CloudWatch Logs and Alarms, IAM roles, Security Groups, and an optional Application Load Balancer (ALB).

# How to Use

1. Configure AWS CLI
   - Ensure that the AWS CLI is installed and configured with the appropriate credentials and region. You can configure it by running the following command and providing your AWS access key, secret key, and default region:

```
aws configure
```

2. Configure AWS Backend

   - Ensure that the backend.tf file is properly configured to store the Terraform state in the specified S3 bucket and DynamoDB table.
   - If using a non-default AWS profile, update the backend.tf and variables.tf configuration to reflect the correct profile.

3. Initialize Terraform
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
   - When you no longer need the infrastructure, you can destroy it using:

```
terraform destroy
```

##  Differences Between ASG with and without ALB

- ASG without an ALB

  - The ASG is created in a public subnet, allowing instances to have public IP addresses.
  - The ASG's security group is open to the entire internet on port 80.

- ASG with an ALB

  - An ALB is created in public subnets with a security group that allows internet access on port 80.
  - The ASG is deployed in a private subnet.
  - The ASG's security group is only open to the ALB's security group on port 80.

## Changing ALB Creation Option

To switch from an ASG module with an ALB to one without it, you'll need to destroy the current module and apply it agaion.

```
terraform destroy -target module.asg
terraform apply
```

## Modules

### VPC Module

The VPC module creates the following resources:

- A VPC with the specified CIDR block
- Public and private subnets across the specified availability zones
- An Internet Gateway (IGW) for the public subnets
- NAT Gateways for the private subnets

### ASG Module

The ASG module creates:

- Auto Scaling Group (ASG) for EC2 instances
- Application Load Balancer (Optional)
- IAM roles and policies for the instances
- Security Groups to control access
- CloudWatch Logs and Alarms for monitoring
- SNS Topic
- SNS Topic subscription

## Resources

### S3 Bucket

An S3 bucket is created to store web content. By default, the index.html file is uploaded to the bucket.

## Variables

| Variable                           | Description                                                                                                            | Example                               |
| ---------------------------------- | ---------------------------------------------------------------------------------------------------------------------- | ------------------------------------- |
| `project_name`                     | Project name for tagging resources                                                                                     | `Customer`                            |
| `profile_name`                     | AWS Profile to be used to create/access resources                                                                      | `default`                             |
| `env`                              | Environment name (Prod, Dev, etc.)                                                                                     | `Prod`                                |
| `region`                           | AWS Region to deploy the resources                                                                                     | `us-west-2`                           |
| `cidr_block`                       | CIDR range of the VPC                                                                                                  | `10.0.0.0/16`                         |
| `subnet_count`                     | Number of public and private subnets (if create_load_balancer flag is set to true, minimum accepted subnet count is 2) | `2`                                   |
| `public_subnet_suffixes`           | CIDR suffixes for public subnets                                                                                       | `["1.0/24", "2.0/24"]`                |
| `private_subnet_suffixes`          | CIDR suffixes for private subnets                                                                                      | `["3.0/24", "4.0/24"]`                |
| `instance_name`                    | Name tag for the EC2 instances                                                                                         | `Web-Server`                          |
| `instance_type`                    | EC2 instance type                                                                                                      | `t2.micro`                            |
| `ami_id`                           | AMI ID for the EC2 instances                                                                                           | `ami-0bfddf4206f1fa7b9`               |
| `extra_tags`                       | Additional tags for resources                                                                                          | See `variables.tf`                    |
| `aws_sns_topic_subscription_email` | Email address of the AWS SNS topic subscription                                                                        | `devops-admin@example.com`            |
| `web_content_bucket_name`          | Name of the S3 bucket where web content is stored                                                                      | `customer-prod-web-content-553550119` |
| `create_load_balancer`             | Boolean to determine if load balancer and related resources should be created                                          | `true`                                |

## Module Outputs

### VPC Module

| Output                    | Description                       |
| ------------------------- | --------------------------------- |
| `vpc_id`                  | ID of the VPC created             |
| `public_subnets`          | Attributes of the public subnets  |
| `private_subnets`         | Attributes of the private subnets |
| `public_route_table_ids`  | IDs of the public route tables    |
| `private_route_table_ids` | IDs of the private route tables   |
